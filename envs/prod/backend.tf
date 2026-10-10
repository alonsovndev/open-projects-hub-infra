terraform {
  backend "s3" {
    bucket       = "ophub-tfstate-241016605697"
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
