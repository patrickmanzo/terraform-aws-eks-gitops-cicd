# Terratest - Infrastructure Tests

This directory contains infrastructure tests using [Terratest](https://terratest.gruntwork.io/).

## Test Types

### Fast Tests (Plan Only)
These tests validate Terraform configuration without creating real resources:
- `TestTerraformValidate` - Validates syntax
- `TestVPCModuleOutputs` - Validates VPC plan
- `TestEKSModulePlan` - Validates EKS plan

### Full Tests (Real Resources)
These tests create real AWS resources and validate them:
- `TestVPCModule` - Creates and validates VPC (~5 min)
- `TestEKSClusterMinimal` - Creates and validates EKS cluster (~20 min)

⚠️ **Warning**: Full tests create real AWS resources and incur costs!

## Running Tests Locally

### Prerequisites
```bash
# Install Go 1.21+
brew install go

# Install dependencies
cd test
go mod download
```

### Run Fast Tests (No AWS Resources)
```bash
# All fast tests
go test -v -short -timeout 10m

# Specific test
go test -v -run TestTerraformValidate -timeout 10m
go test -v -run TestVPCModuleOutputs -timeout 10m
```

### Run Full Tests (Creates AWS Resources)
```bash
# Configure AWS credentials first
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"

# VPC test (~5 minutes)
go test -v -run TestVPCModule -timeout 30m

# EKS test (~20 minutes, expensive!)
go test -v -run TestEKSClusterMinimal -timeout 45m
```

## CI/CD Integration

Tests run automatically via GitHub Actions:
- **On PR**: Fast tests only (plan validation)
- **Manual trigger**: Full tests available

## Adding New Tests

1. Create a new `*_test.go` file
2. Use `t.Parallel()` for concurrent execution
3. Use `defer terraform.Destroy()` to clean up resources
4. Use `random.UniqueId()` to avoid naming conflicts
