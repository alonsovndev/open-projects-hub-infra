terraform {
  backend "s3" {
    bucket       = "ophub-tfstate-044986460195"
    key          = "prod/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
