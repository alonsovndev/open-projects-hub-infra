data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_vpc" "default" {
  default = true
}

# Some AZs in a region do not offer every instance type.
data "aws_ec2_instance_type_offerings" "supported" {
  location_type = "availability-zone"

  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
}

data "aws_subnets" "supported" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = data.aws_ec2_instance_type_offerings.supported.locations
  }
}

# Cloudflare's published edge ranges. The host only answers the proxy, never the open internet.
resource "aws_ec2_managed_prefix_list" "edge" {
  name           = "${var.name}-edge"
  address_family = "IPv4"
  max_entries    = 20

  dynamic "entry" {
    for_each = toset(var.edge_ipv4_cidrs)

    content {
      cidr        = entry.value
      description = "Cloudflare edge"
    }
  }
}

resource "aws_security_group" "api" {
  name        = "${var.name}-api"
  description = "API host: HTTPS from Cloudflare only, no SSH (use SSM Session Manager)"
  vpc_id      = data.aws_vpc.default.id

  # The description cannot change in place; replacing the group would detach it from the live host.
  # The group first created here said "HTTP from CloudFront only"; the rules are what counts.
  lifecycle {
    ignore_changes = [description]
  }
}

resource "aws_vpc_security_group_ingress_rule" "https_from_edge" {
  security_group_id = aws_security_group.api.id
  description       = "HTTPS from Cloudflare edge servers"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = aws_ec2_managed_prefix_list.edge.id
}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.api.id
  description       = "Image pulls, SSM, S3, SMTP and AI provider calls"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api" {
  name               = "${var.name}-api-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "api_access" {
  statement {
    sid     = "ReadAppParameters"
    actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter_prefix}",
      "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter_prefix}/*",
    ]
  }
}

resource "aws_iam_role_policy" "api_access" {
  name   = "app-parameters"
  role   = aws_iam_role.api.id
  policy = data.aws_iam_policy_document.api_access.json
}

resource "aws_iam_instance_profile" "api" {
  name = "${var.name}-api"
  role = aws_iam_role.api.name
}

resource "aws_instance" "api" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = sort(data.aws_subnets.supported.ids)[0]
  vpc_security_group_ids = [aws_security_group.api.id]
  iam_instance_profile   = aws_iam_instance_profile.api.name

  # Standard mode throttles instead of billing surplus vCPU-hours on top of the instance price.
  credit_specification {
    cpu_credits = "standard"
  }

  disable_api_termination = true

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    compose_version = var.compose_version
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_gb
    encrypted   = true
  }

  tags = {
    Name = "${var.name}-api"
  }

  # Postgres data lives on this instance's root volume: a newer AMI, edited
  # user_data or a changed default-subnet list must never trigger a replacement
  # (and data loss) on a later apply.
  lifecycle {
    ignore_changes  = [ami, user_data, subnet_id]
    prevent_destroy = true
  }
}

resource "aws_eip" "api" {
  instance = aws_instance.api.id
  domain   = "vpc"

  tags = {
    Name = "${var.name}-api"
  }
}
