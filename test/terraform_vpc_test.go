package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestVPCModule tests the VPC module in isolation
// This creates real AWS resources and destroys them after the test
// Run with: go test -v -run TestVPCModule -timeout 30m
func TestVPCModule(t *testing.T) {
	t.Parallel()

	// Generate a unique name to avoid conflicts
	uniqueID := random.UniqueId()
	awsRegion := "us-east-1"

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/vpc",
		Vars: map[string]interface{}{
			"environment":          "test",
			"project":              fmt.Sprintf("terratest-%s", uniqueID),
			"name_prefix":          fmt.Sprintf("test-%s", uniqueID),
			"vpc_cidr_block":       "10.99.0.0/16",
			"public_subnet_cidrs":  []string{"10.99.1.0/24", "10.99.2.0/24"},
			"private_subnet_cidrs": []string{"10.99.11.0/24", "10.99.12.0/24"},
			"common_tags": map[string]string{
				"Environment": "test",
				"ManagedBy":   "Terratest",
				"TestID":      uniqueID,
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
		NoColor: true,
	})

	// Destroy resources at the end of the test
	defer terraform.Destroy(t, terraformOptions)

	// Deploy the VPC
	terraform.InitAndApply(t, terraformOptions)

	// Get outputs
	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	publicSubnetIDs := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	privateSubnetIDs := terraform.OutputList(t, terraformOptions, "private_subnet_ids")

	// Validate VPC was created
	assert.NotEmpty(t, vpcID, "VPC ID should not be empty")

	// Validate subnets were created
	assert.Equal(t, 2, len(publicSubnetIDs), "Should have 2 public subnets")
	assert.Equal(t, 2, len(privateSubnetIDs), "Should have 2 private subnets")

	// Validate VPC exists in AWS
	vpc := aws.GetVpcById(t, vpcID, awsRegion)
	assert.NotNil(t, vpc, "VPC should exist")

	// Validate subnets exist using terraform outputs
	assert.Equal(t, 2, len(publicSubnetIDs), "Should have 2 public subnets")
	assert.Equal(t, 2, len(privateSubnetIDs), "Should have 2 private subnets")

	t.Log("✅ VPC module test passed!")
}

// TestVPCModuleOutputs validates VPC module outputs without creating resources
// This is a faster test that just validates the plan
func TestVPCModuleOutputs(t *testing.T) {
	t.Parallel()

	uniqueID := random.UniqueId()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/vpc",
		Vars: map[string]interface{}{
			"environment":          "test",
			"project":              fmt.Sprintf("terratest-%s", uniqueID),
			"name_prefix":          fmt.Sprintf("test-%s", uniqueID),
			"vpc_cidr_block":       "10.99.0.0/16",
			"public_subnet_cidrs":  []string{"10.99.1.0/24", "10.99.2.0/24"},
			"private_subnet_cidrs": []string{"10.99.11.0/24", "10.99.12.0/24"},
			"common_tags": map[string]string{
				"Environment": "test",
				"ManagedBy":   "Terratest",
			},
		},
		NoColor:      true,
		PlanFilePath: fmt.Sprintf("/tmp/vpc-plan-%s", uniqueID),
	})

	// Just run init and plan (no apply)
	terraform.Init(t, terraformOptions)
	planOutput := terraform.Plan(t, terraformOptions)

	// Validate plan contains expected resources
	assert.Contains(t, planOutput, "aws_vpc.this", "Plan should include VPC resource")
	assert.Contains(t, planOutput, "aws_subnet.public", "Plan should include public subnets")
	assert.Contains(t, planOutput, "aws_subnet.private", "Plan should include private subnets")
	assert.Contains(t, planOutput, "aws_nat_gateway.this", "Plan should include NAT gateway")
	assert.Contains(t, planOutput, "aws_internet_gateway.this", "Plan should include internet gateway")

	t.Log("✅ VPC module plan validation passed!")
}
