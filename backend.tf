terraform {
  backend "s3" {
    bucket       = "terraform-state-backend-343104031682-finance-dev"
    region       = "us-east-1"
    key          = "terraform.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}
