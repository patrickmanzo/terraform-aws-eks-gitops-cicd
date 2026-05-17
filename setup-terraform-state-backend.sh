#!/bin/bash

# =============================================================================
# Terraform State Backend Setup Script
# =============================================================================
# This script sets up AWS S3 bucket for Terraform state management using
# S3 native locking (use_lockfile = true) instead of DynamoDB.
#
# LAB MODE (default):
# - Shorter lifecycle policies for cost optimization
# - No Object Lock for easy deletion
# - Basic encryption with AES256
# - Shorter retention periods
#
# PRODUCTION MODE (commented options):
# - Object Lock protection against deletion
# - KMS encryption for enhanced security
# - Longer retention periods
#
# Usage:
#   ./setup-terraform-state-backend.sh --create     # Create backend resources
#   ./setup-terraform-state-backend.sh --delete     # Delete backend resources
# =============================================================================

set -e  # Exit on any error
set -u  # Exit on undefined variable

# Configuration
BUCKET_NAME="terraform-state-backend-343104031682-finance-dev"
REGION="us-east-1"

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    log_success "AWS credentials verified"
}

# Function to create backend resources
create_backend() {
    log_info "🚀 Creating Terraform backend resources..."

    # Create bucket WITHOUT Object Lock for easier deletion in lab
    log_info "📦 Creating S3 bucket..."
    aws s3api create-bucket \
      --bucket $BUCKET_NAME \
      --region $REGION

    # Configure bucket versioning (required for S3 native locking)
    log_info "🔄 Enabling versioning..."
    aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled

    # Configure bucket encryption
    log_info "🔐 Configuring encryption..."
    aws s3api put-bucket-encryption --bucket $BUCKET_NAME --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        },
        "BucketKeyEnabled": true
      }]
    }'

    # PRODUCTION: Consider using KMS encryption (uncomment and configure for production)
    # aws s3api put-bucket-encryption --bucket $BUCKET_NAME --server-side-encryption-configuration '{
    #   "Rules": [{
    #     "ApplyServerSideEncryptionByDefault": {
    #       "SSEAlgorithm": "aws:kms",
    #       "KMSMasterKeyID": "arn:aws:kms:region:account-id:key/key-id"
    #     },
    #     "BucketKeyEnabled": true
    #   }]
    # }'

    # Block public access
    log_info "🚫 Blocking public access..."
    aws s3api put-public-access-block --bucket $BUCKET_NAME --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

    # Set ownership controls
    log_info "👤 Setting ownership controls..."
    aws s3api put-bucket-ownership-controls --bucket $BUCKET_NAME --ownership-controls \
      Rules='[{ObjectOwnership=BucketOwnerEnforced}]'

    # Create bucket policy for secure transport
    log_info "🔒 Setting security policy..."
    aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy '{
      "Version": "2012-10-17",
      "Statement": [{
        "Sid": "DenyInsecureConnections",
        "Effect": "Deny",
        "Principal": "*",
        "Action": "s3:*",
        "Resource": [
          "arn:aws:s3:::'$BUCKET_NAME'",
          "arn:aws:s3:::'$BUCKET_NAME'/*"
        ],
        "Condition": {
          "Bool": {
            "aws:SecureTransport": "false"
          }
        }
      }]
    }'

    # LAB-FRIENDLY: Shorter lifecycle for cost optimization
    log_info "📅 Configuring lifecycle policy (lab-optimized)..."
    aws s3api put-bucket-lifecycle-configuration --bucket $BUCKET_NAME --lifecycle-configuration '{
      "Rules": [{
        "ID": "TerraformStateLifecycleLab",
        "Status": "Enabled",
        "Filter": {
          "Prefix": ""
        },
        "NoncurrentVersionExpiration": {
          "NoncurrentDays": 7
        },
        "AbortIncompleteMultipartUpload": {
          "DaysAfterInitiation": 1
        }
      }]
    }'

    # PRODUCTION: Longer lifecycle for better protection (uncomment for production)
    # aws s3api put-bucket-lifecycle-configuration --bucket $BUCKET_NAME --lifecycle-configuration '{
    #   "Rules": [{
    #     "ID": "TerraformStateLifecycleProduction",
    #     "Status": "Enabled",
    #     "Filter": {
    #       "Prefix": ""
    #     },
    #     "NoncurrentVersionExpiration": {
    #       "NoncurrentDays": 90
    #     },
    #     "AbortIncompleteMultipartUpload": {
    #       "DaysAfterInitiation": 7
    #     }
    #   }]
    # }'

    # PRODUCTION: Configure Object Lock default retention (uncomment for production)
    # log_info "🔒 Configuring Object Lock default retention..."
    # aws s3api put-object-lock-configuration \
    #   --bucket $BUCKET_NAME \
    #   --object-lock-configuration '{
    #     "ObjectLockEnabled": "Enabled",
    #     "Rule": {
    #       "DefaultRetention": {
    #         "Mode": "GOVERNANCE",
    #         "Days": 30
    #       }
    #     }
    #   }'

    log_success "✅ Backend setup complete!"
    echo ""
    log_info "📋 Resource Summary:"
    log_info "   S3 Bucket: $BUCKET_NAME"
    log_info "   Region: $REGION"
    log_info "   Locking: S3 Native (use_lockfile = true)"
    echo ""
    log_info "🔧 Configuration Applied:"
    log_info "   ✓ S3 native locking (no DynamoDB needed)"
    log_info "   ✓ Lab-optimized lifecycle (7 days for non-current versions)"
    log_info "   ✓ AES256 encryption (not KMS for cost savings)"
    log_info "   ✓ No Object Lock (easier deletion)"
    log_info "   ✓ Versioning enabled (required for state locking)"
    echo ""
    log_info "💡 For production use, uncomment the production options in this script"
    echo ""
}

# Function to delete all backend resources
delete_backend() {
    log_warning "🗑️  Starting backend cleanup..."

    # Delete S3 bucket with all versions and delete markers
    log_info "🧹 Emptying and deleting S3 bucket: $BUCKET_NAME..."
    if aws s3api head-bucket --bucket $BUCKET_NAME 2>/dev/null; then

        # Step 1: Delete all object versions
        log_info "🗑️  Deleting all object versions..."
        aws s3api list-object-versions --bucket $BUCKET_NAME --output json 2>/dev/null | \
        jq -r '.Versions[]? | "\(.Key)\t\(.VersionId)"' 2>/dev/null | \
        while IFS=$'\t' read -r key version; do
            if [ -n "$key" ] && [ -n "$version" ]; then
                aws s3api delete-object --bucket $BUCKET_NAME --key "$key" --version-id "$version" 2>/dev/null || true
                echo "  Deleted version: $key ($version)"
            fi
        done

        # Step 2: Delete all delete markers
        log_info "🗑️  Deleting all delete markers..."
        aws s3api list-object-versions --bucket $BUCKET_NAME --output json 2>/dev/null | \
        jq -r '.DeleteMarkers[]? | "\(.Key)\t\(.VersionId)"' 2>/dev/null | \
        while IFS=$'\t' read -r key version; do
            if [ -n "$key" ] && [ -n "$version" ]; then
                aws s3api delete-object --bucket $BUCKET_NAME --key "$key" --version-id "$version" 2>/dev/null || true
                echo "  Deleted marker: $key ($version)"
            fi
        done

        # Step 3: Delete any remaining objects (non-versioned)
        log_info "🗑️  Cleaning up remaining objects..."
        aws s3 rm "s3://$BUCKET_NAME" --recursive 2>/dev/null || true

        # Step 4: Delete the bucket
        log_info "🗑️  Deleting bucket..."
        if aws s3api delete-bucket --bucket $BUCKET_NAME --region $REGION 2>/dev/null; then
            log_success "S3 bucket deleted"
        else
            log_error "Failed to delete bucket - may have remaining objects"
            log_info "Attempting force delete with s3 rb..."
            aws s3 rb "s3://$BUCKET_NAME" --force 2>/dev/null || log_error "Force delete also failed"
        fi
    else
        log_warning "S3 bucket $BUCKET_NAME does not exist (skipping deletion)"
    fi

    log_success "🎉 Backend cleanup complete!"
    echo ""
    log_info "💰 Resources deleted for cost optimization:"
    log_info "  🗑️  S3 Bucket: $BUCKET_NAME (all versions)"
    echo ""
    log_info "💡 Ready for next lab deployment!"
    echo ""
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Lab-friendly Terraform backend management script"
    echo "Uses S3 native locking (no DynamoDB required)"
    echo ""
    echo "Options:"
    echo "  --create     Create backend resources (default)"
    echo "  --delete     Delete all backend resources"
    echo "  --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                # Create backend"
    echo "  $0 --create       # Create backend"
    echo "  $0 --delete       # Delete backend"
    echo ""
}

# Main function
main() {
    check_aws_credentials

    case "${1:-create}" in
        --create|create)
            create_backend
            ;;
        --delete|delete)
            echo ""
            log_warning "⚠️  This will permanently delete:"
            log_warning "   • S3 bucket: $BUCKET_NAME (and all contents)"
            echo ""
            read -p "Are you sure? Type 'DELETE' to confirm: " confirm
            if [ "$confirm" = "DELETE" ]; then
                delete_backend
            else
                log_info "Operation cancelled"
            fi
            ;;
        --help|help|-h)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
