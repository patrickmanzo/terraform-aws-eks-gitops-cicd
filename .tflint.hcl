plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Disable rules that are too strict for development/lab environments
rule "terraform_required_providers" {
  enabled = false
}

rule "terraform_required_version" {
  enabled = false
}

# Disable unused declarations - common in modular Terraform with optional features
rule "terraform_unused_declarations" {
  enabled = false
}

# Disable typed variables check - some legacy variables may not have types
rule "terraform_typed_variables" {
  enabled = false
}
