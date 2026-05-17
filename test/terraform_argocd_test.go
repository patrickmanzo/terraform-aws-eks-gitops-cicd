package test

import (
	"fmt"
	"os/exec"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// TestArgoCDWithKind validates the ArgoCD Helm chart and values using a Kind cluster
// This test:
// 1. Creates a Kind cluster
// 2. Deploys ArgoCD using Helm (same chart/values as the Terraform module)
// 3. Validates all pods are running
// 4. Cleans up
//
// Run with: go test -v -run TestArgoCDWithKind -timeout 15m
func TestArgoCDWithKind(t *testing.T) {
	t.Parallel()

	uniqueID := strings.ToLower(random.UniqueId())
	clusterName := fmt.Sprintf("argocd-test-%s", uniqueID)
	namespace := "argocd"

	// Create Kind cluster
	createKindCluster(t, clusterName)
	defer deleteKindCluster(t, clusterName)

	// Get kubeconfig for the Kind cluster
	kubeconfigPath := getKindKubeconfig(t, clusterName)

	// Create kubectl options
	kubectlOptions := k8s.NewKubectlOptions("", kubeconfigPath, namespace)

	// Create namespace
	k8s.CreateNamespace(t, kubectlOptions, namespace)

	// Deploy ArgoCD using Helm (mimics what Terraform does)
	deployArgoCDWithHelm(t, kubeconfigPath, namespace)

	// Wait for all ArgoCD pods to be ready
	waitForArgoCDPods(t, kubectlOptions)

	// Validate ArgoCD components
	validateArgoCDDeployment(t, kubectlOptions)

	t.Log("✅ ArgoCD Kind test passed!")
}

// TestArgoCDValuesValidation validates the values.yaml without deploying
// Faster test that just checks Helm template rendering
func TestArgoCDValuesValidation(t *testing.T) {
	t.Parallel()

	// Ensure helm repo is added
	addCmd := exec.Command("helm", "repo", "add", "argo", "https://argoproj.github.io/argo-helm")
	addCmd.Run() // Ignore error if already exists

	updateCmd := exec.Command("helm", "repo", "update")
	updateCmd.Run()

	// Helm template the chart with our values to catch config errors
	cmd := exec.Command("helm", "template", "argo-cd",
		"argo/argo-cd",
		"--version", "9.1.9",
		"--namespace", "argocd",
		"--values", "../modules/argo_cd/values.yaml",
		"--set", "configs.secret.argocdServerAdminPassword=$2a$10$test",
	)

	output, err := cmd.CombinedOutput()
	require.NoError(t, err, "Helm template should succeed. Output: %s", string(output))

	outputStr := string(output)

	// Validate expected resources are in the template
	assert.Contains(t, outputStr, "argocd-server", "Should contain argocd-server")
	assert.Contains(t, outputStr, "argocd-repo-server", "Should contain repo-server")
	assert.Contains(t, outputStr, "argocd-redis", "Should contain redis")
	assert.Contains(t, outputStr, "argocd-application-controller", "Should contain application-controller")

	// Validate our custom config is applied
	assert.Contains(t, outputStr, "server.insecure", "Should have server.insecure config")

	t.Log("✅ ArgoCD values validation passed!")
}

// Helper functions

func createKindCluster(t *testing.T, name string) {
	t.Logf("Creating Kind cluster: %s", name)

	cmd := exec.Command("kind", "create", "cluster", "--name", name, "--wait", "60s")
	output, err := cmd.CombinedOutput()
	require.NoError(t, err, "Failed to create Kind cluster: %s", string(output))

	t.Logf("Kind cluster created: %s", name)
}

func deleteKindCluster(t *testing.T, name string) {
	t.Logf("Deleting Kind cluster: %s", name)

	cmd := exec.Command("kind", "delete", "cluster", "--name", name)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Logf("Warning: Failed to delete Kind cluster: %s", string(output))
	}
}

func getKindKubeconfig(t *testing.T, name string) string {
	kubeconfigPath := fmt.Sprintf("/tmp/kubeconfig-%s", name)
	writeCmd := exec.Command("bash", "-c", fmt.Sprintf("kind get kubeconfig --name %s > %s", name, kubeconfigPath))
	err := writeCmd.Run()
	require.NoError(t, err, "Failed to get Kind kubeconfig")

	return kubeconfigPath
}

func deployArgoCDWithHelm(t *testing.T, kubeconfigPath, namespace string) {
	t.Log("Deploying ArgoCD with Helm...")

	// Add Argo Helm repo
	addRepo := exec.Command("helm", "repo", "add", "argo", "https://argoproj.github.io/argo-helm")
	addRepo.Env = append(addRepo.Environ(), fmt.Sprintf("KUBECONFIG=%s", kubeconfigPath))
	addRepo.Run() // Ignore error if already exists

	updateRepo := exec.Command("helm", "repo", "update")
	updateRepo.Env = append(updateRepo.Environ(), fmt.Sprintf("KUBECONFIG=%s", kubeconfigPath))
	updateRepo.Run()

	// Install ArgoCD with our values
	installCmd := exec.Command("helm", "install", "argo-cd",
		"argo/argo-cd",
		"--version", "9.1.9",
		"--namespace", namespace,
		"--create-namespace",
		"--values", "../modules/argo_cd/values.yaml",
		"--set", "configs.secret.argocdServerAdminPassword=$2a$10$8YJR5gDoPPxlIAhnKrqDO.hcoJPiD44rMRwt4XxpV/m2ObWITUrQu",
		"--set", "server.ingress.enabled=false", // Disable ingress for Kind (no ALB)
		"--wait",
		"--timeout", "5m",
	)
	installCmd.Env = append(installCmd.Environ(), fmt.Sprintf("KUBECONFIG=%s", kubeconfigPath))

	output, err := installCmd.CombinedOutput()
	require.NoError(t, err, "Failed to install ArgoCD: %s", string(output))

	t.Log("ArgoCD deployed successfully")
}

func waitForArgoCDPods(t *testing.T, kubectlOptions *k8s.KubectlOptions) {
	t.Log("Waiting for ArgoCD pods to be ready...")

	expectedPods := []string{
		"argo-cd-argocd-server",
		"argo-cd-argocd-repo-server",
		"argo-cd-argocd-redis",
		"argo-cd-argocd-application-controller",
	}

	for _, podPrefix := range expectedPods {
		retry.DoWithRetry(t, fmt.Sprintf("Waiting for %s", podPrefix), 30, 10*time.Second, func() (string, error) {
			pods := k8s.ListPods(t, kubectlOptions, metav1.ListOptions{})
			for _, pod := range pods {
				if strings.HasPrefix(pod.Name, podPrefix) {
					if k8s.IsPodAvailable(&pod) {
						return fmt.Sprintf("Pod %s is ready", pod.Name), nil
					}
					return "", fmt.Errorf("pod %s exists but not ready: %s", pod.Name, pod.Status.Phase)
				}
			}
			return "", fmt.Errorf("pod with prefix %s not found", podPrefix)
		})
	}

	t.Log("All ArgoCD pods are ready")
}

func validateArgoCDDeployment(t *testing.T, kubectlOptions *k8s.KubectlOptions) {
	t.Log("Validating ArgoCD deployment...")

	// Check services exist
	services := k8s.ListServices(t, kubectlOptions, metav1.ListOptions{})
	serviceNames := make([]string, len(services))
	for i, svc := range services {
		serviceNames[i] = svc.Name
	}

	assert.Contains(t, serviceNames, "argo-cd-argocd-server", "ArgoCD server service should exist")
	assert.Contains(t, serviceNames, "argo-cd-argocd-repo-server", "ArgoCD repo-server service should exist")

	// Check secrets exist
	secrets, err := k8s.RunKubectlAndGetOutputE(t, kubectlOptions, "get", "secrets", "-o", "name")
	require.NoError(t, err)

	assert.Contains(t, secrets, "argocd-secret", "ArgoCD secret should exist")

	// Validate no pods in error state
	pods := k8s.ListPods(t, kubectlOptions, metav1.ListOptions{})
	for _, pod := range pods {
		assert.NotEqual(t, "Failed", string(pod.Status.Phase), "Pod %s should not be in Failed state", pod.Name)
		assert.NotEqual(t, "Unknown", string(pod.Status.Phase), "Pod %s should not be in Unknown state", pod.Name)

		// Check no containers in error state
		for _, containerStatus := range pod.Status.ContainerStatuses {
			if containerStatus.State.Waiting != nil {
				assert.NotContains(t, containerStatus.State.Waiting.Reason, "Error",
					"Container %s in pod %s should not have error", containerStatus.Name, pod.Name)
			}
		}
	}

	t.Log("ArgoCD deployment validation passed")
}
