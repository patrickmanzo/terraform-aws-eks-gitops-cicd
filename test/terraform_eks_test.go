package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestEKSClusterMinimal deploys a minimal EKS cluster and validates it
// WARNING: This test creates real AWS resources and can take 15-20 minutes
// Run with: go test -v -run TestEKSClusterMinimal -timeout 45m
func TestEKSClusterMinimal(t *testing.T) {
	// Skip in short mode (for CI that doesn't want to spend money)
	if testing.Short() {
		t.Skip("Skipping EKS test in short mode (creates real resources)")
	}

	t.Parallel()

	uniqueID := random.UniqueId()
	awsRegion := "us-east-1"

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../",
		VarFiles:     []string{"minimal.tfvars"},
		Vars: map[string]interface{}{
			"project":         fmt.Sprintf("test-%s", uniqueID),
			"environment":     "test",
			"github_pat":      "test-token",
			"github_user":     "test-user",
			"github_repo_url": "https://github.com/test/repo.git",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
		NoColor: true,
		// Increase timeouts for EKS
		MaxRetries:         3,
		TimeBetweenRetries: 10 * time.Second,
	})

	// Destroy resources at the end
	defer terraform.Destroy(t, terraformOptions)

	// Deploy infrastructure
	terraform.InitAndApply(t, terraformOptions)

	// Get outputs
	clusterName := terraform.Output(t, terraformOptions, "eks_cluster_name")
	clusterEndpoint := terraform.Output(t, terraformOptions, "eks_cluster_endpoint")
	vpcID := terraform.Output(t, terraformOptions, "vpc_id")

	// Validate outputs
	assert.NotEmpty(t, clusterName, "EKS cluster name should not be empty")
	assert.NotEmpty(t, clusterEndpoint, "EKS cluster endpoint should not be empty")
	assert.NotEmpty(t, vpcID, "VPC ID should not be empty")
	assert.Contains(t, clusterEndpoint, "eks.amazonaws.com", "Endpoint should be EKS endpoint")

	// Configure kubectl
	kubeconfig := fmt.Sprintf("/tmp/kubeconfig-%s", uniqueID)

	// Get kubeconfig using AWS CLI
	k8s.RunKubectl(t, k8s.NewKubectlOptions("", "", "default"),
		"config", "view") // Just to verify kubectl works

	// Test Kubernetes connectivity
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfig, "default")

	// Wait for nodes to be ready
	k8s.WaitUntilAllNodesReady(t, kubectlOptions, 10, 30*time.Second)

	// Validate nodes are ready
	nodes := k8s.GetNodes(t, kubectlOptions)
	assert.GreaterOrEqual(t, len(nodes), 1, "Should have at least 1 node")

	for _, node := range nodes {
		t.Logf("Node: %s", node.Name)
		// Check node is Ready
		for _, condition := range node.Status.Conditions {
			if condition.Type == "Ready" {
				assert.Equal(t, "True", string(condition.Status), "Node should be Ready")
			}
		}
	}

	// Validate core namespaces exist
	output, err := k8s.RunKubectlAndGetOutputE(t, kubectlOptions, "get", "namespaces", "-o", "name")
	assert.NoError(t, err, "Should be able to list namespaces")
	assert.Contains(t, output, "kube-system", "kube-system namespace should exist")
	assert.Contains(t, output, "default", "default namespace should exist")

	t.Log("✅ EKS cluster test passed!")
}

// TestEKSModulePlan validates EKS module configuration without deploying
// This is a fast test that just validates the plan
func TestEKSModulePlan(t *testing.T) {
	t.Parallel()

	uniqueID := random.UniqueId()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../",
		VarFiles:     []string{"minimal.tfvars"},
		Vars: map[string]interface{}{
			"github_pat":      "test-token",
			"github_user":     "test-user",
			"github_repo_url": "https://github.com/test/repo.git",
		},
		NoColor:      true,
		PlanFilePath: fmt.Sprintf("/tmp/eks-plan-%s", uniqueID),
	})

	// Initialize with backend disabled
	terraform.RunTerraformCommand(t, terraformOptions, "init", "-backend=false")

	// Run plan
	planOutput := terraform.Plan(t, terraformOptions)

	// Validate plan contains expected resources
	assert.Contains(t, planOutput, "module.vpc", "Plan should include VPC module")
	assert.Contains(t, planOutput, "module.eks", "Plan should include EKS module")
	assert.Contains(t, planOutput, "module.ecr", "Plan should include ECR module")
	assert.Contains(t, planOutput, "aws_eks_cluster", "Plan should include EKS cluster")
	assert.Contains(t, planOutput, "aws_eks_node_group", "Plan should include EKS node group")

	t.Log("✅ EKS module plan validation passed!")
}
