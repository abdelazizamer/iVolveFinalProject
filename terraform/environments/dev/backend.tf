terraform {
  backend "s3" {
    bucket       = "clouddevopsproject-397845934845-us-east-1-tfstate"
    key          = "clouddevops/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

