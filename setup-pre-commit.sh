#!/bin/bash
set -e

echo "🔧 Setting up pre-commit hooks and dependencies..."

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    MINGW*|MSYS*|CYGWIN*) MACHINE=Windows;;
    *)          MACHINE="UNKNOWN:${OS}"
esac

echo "📦 Detected OS: $MACHINE"

# Install pre-commit
echo "📦 Installing pre-commit..."
if command -v pre-commit &> /dev/null; then
    echo "✅ pre-commit already installed"
elif command -v pipx &> /dev/null; then
    pipx install pre-commit
elif [ "$MACHINE" = "Mac" ]; then
    brew install pre-commit
elif [ "$MACHINE" = "Linux" ]; then
    # Try pipx first, install it if needed
    if ! command -v pipx &> /dev/null; then
        echo "📦 Installing pipx first..."
        sudo apt-get update && sudo apt-get install -y pipx 2>/dev/null || {
            python3 -m pip install --user pipx 2>/dev/null || pip3 install --user pipx
        }
        pipx ensurepath
    fi
    pipx install pre-commit
else
    echo "❌ Could not install pre-commit. Please install manually."
    exit 1
fi

# Install tflint
echo "📦 Installing tflint..."
if ! command -v tflint &> /dev/null; then
    if [ "$MACHINE" = "Mac" ]; then
        brew install tflint
    elif [ "$MACHINE" = "Linux" ]; then
        curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
    else
        echo "⚠️  Please install tflint manually: https://github.com/terraform-linters/tflint"
    fi
else
    echo "✅ tflint already installed"
fi

# Install tflint AWS plugin
echo "📦 Installing tflint AWS plugin..."
tflint --init || true

# Install terraform-docs
echo "📦 Installing terraform-docs..."
if ! command -v terraform-docs &> /dev/null; then
    if [ "$MACHINE" = "Mac" ]; then
        brew install terraform-docs
    elif [ "$MACHINE" = "Linux" ]; then
        curl -sSLo ./terraform-docs.tar.gz https://terraform-docs.io/dl/v0.18.0/terraform-docs-v0.18.0-$(uname)-amd64.tar.gz
        tar -xzf terraform-docs.tar.gz
        chmod +x terraform-docs
        sudo mv terraform-docs /usr/local/bin/
        rm terraform-docs.tar.gz
    else
        echo "⚠️  Please install terraform-docs manually: https://terraform-docs.io"
    fi
else
    echo "✅ terraform-docs already installed"
fi

# Install trivy
echo "📦 Installing trivy..."
if ! command -v trivy &> /dev/null; then
    if [ "$MACHINE" = "Mac" ]; then
        brew install trivy
    elif [ "$MACHINE" = "Linux" ]; then
        sudo apt-get install -y wget apt-transport-https gnupg lsb-release 2>/dev/null || true
        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add - 2>/dev/null || true
        echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list 2>/dev/null || true
        sudo apt-get update 2>/dev/null && sudo apt-get install -y trivy 2>/dev/null || {
            # Fallback: direct download
            curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
        }
    else
        echo "⚠️  Please install trivy manually: https://aquasecurity.github.io/trivy"
    fi
else
    echo "✅ trivy already installed"
fi

# Install pre-commit hooks
echo "📦 Installing pre-commit hooks..."
pre-commit install

# Add helm repo for ArgoCD validation
echo "📦 Adding Argo Helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

echo ""
echo "✅ Setup complete! Tools installed:"
echo "   - pre-commit: $(pre-commit --version)"
echo "   - tflint: $(tflint --version 2>/dev/null | head -1 || echo 'not installed')"
echo "   - terraform-docs: $(terraform-docs --version 2>/dev/null || echo 'not installed')"
echo "   - trivy: $(trivy --version 2>/dev/null | head -1 || echo 'not installed')"
echo ""
echo "🚀 Run 'pre-commit run --all-files' to test all hooks"
