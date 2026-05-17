package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
)

// TestTerraformValidate validates that the Terraform configuration is syntactically valid
// This is a fast test that doesn't create any resources
func TestTerraformValidate(t *testing.T) {
	t.Parallel()

	// Note: terraform validate doesn't accept -var-file, so we don't include VarFiles here
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../",
		NoColor:      true,
	})

	// Run terraform init and validate
	terraform.Init(t, terraformOptions)
	terraform.Validate(t, terraformOptions)
}

// TestTerraformPlanMinimal runs terraform plan with minimal configuration
// This validates the configuration without creating resources
func TestTerraformPlanMinimal(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../",
		VarFiles:     []string{"minimal.tfvars"},
		Vars: map[string]interface{}{
			"github_pat":      "test-token",
			"github_user":     "test-user",
			"github_repo_url": "https://github.com/test/repo.git",
		},
		NoColor: true,
	})

	// Run init with -backend=false to skip S3 backend
	terraform.RunTerraformCommand(t, terraformOptions, "init", "-backend=false", "-no-color")

	// Run plan (won't actually create resources)
	terraform.Plan(t, terraformOptions)
}
