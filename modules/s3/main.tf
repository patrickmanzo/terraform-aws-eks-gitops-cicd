
# --------------------------------------------------------------------------------------
# 1. S3 Bucket Resource
# --------------------------------------------------------------------------------------
resource "aws_s3_bucket" "this" {
  bucket        = var.app_bucket_name
  force_destroy = var.force_destroy_on_delete # Be cautious with this in production!

  tags = merge(var.common_tags, {
    Name               = var.app_bucket_name
    ResourceType       = "S3Bucket"
    Service            = "S3"
    Purpose            = "ApplicationStorage"
    DataClassification = "Internal"
  })
}

# --------------------------------------------------------------------------------------
# 2. S3 Bucket Public Access Block (HIGHLY RECOMMENDED FOR SECURITY)
# --------------------------------------------------------------------------------------
# This ensures that the bucket is never publicly accessible, regardless of other settings.
resource "aws_s3_bucket_public_access_block" "this" {
  count  = var.block_public_access ? 1 : 0 # Only apply if blocking public access
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --------------------------------------------------------------------------------------
# 3. S3 Bucket Server-Side Encryption (HIGHLY RECOMMENDED FOR COMPLIANCE)
# --------------------------------------------------------------------------------------
# Enforces encryption of all objects stored in the bucket.
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.sse_algorithm # AES256 for S3-managed, aws:kms for KMS
      # kms_master_key_id = var.kms_key_arn # Only if sse_algorithm is aws:kms
    }
  }
}

# --------------------------------------------------------------------------------------
# 4. S3 Bucket Versioning (RECOMMENDED FOR DATA DURABILITY AND RECOVERY)
# --------------------------------------------------------------------------------------
# Keeps multiple versions of objects, protecting against accidental deletion or overwrites.
resource "aws_s3_bucket_versioning" "this" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

# --------------------------------------------------------------------------------------
# 5. S3 Bucket Logging (RECOMMENDED FOR AUDITING AND SECURITY)
# --------------------------------------------------------------------------------------
# Delivers access logs to a target bucket, providing a record of requests made to the bucket.
resource "aws_s3_bucket_logging" "this" {
  count         = var.enable_access_logging ? 1 : 0
  bucket        = aws_s3_bucket.this.id
  target_bucket = var.log_bucket_name
  target_prefix = "${var.app_bucket_name}/" # Optional: add a prefix to logs

  depends_on = [aws_s3_bucket.this] # Ensure bucket exists first
}

# --------------------------------------------------------------------------------------
# 6. S3 Bucket Lifecycle Configuration (RECOMMENDED FOR COST OPTIMIZATION)
# --------------------------------------------------------------------------------------
# Define rules to transition objects to cheaper storage classes or expire them.
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  # This is the "default" rule that applies to the entire bucket
  rule {
    id     = "default"
    status = "Enabled"
    filter { # This filter block is always present for the default rule
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    expiration {
      days = 365
    }
  }

  # This dynamic block processes custom rules provided via var.lifecycle_rules
  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.status

      # Ensure a filter block is always created for dynamic rules
      filter {
        # Use the prefix from the input rule, or default to an empty string if not provided
        prefix = lookup(rule.value, "prefix", "") # <--- IMPORTANT: Default to "" here
        # If you wanted to support tags filtering for specific rules, you would add logic here
        # tags = lookup(rule.value, "tags", null) # If using tags
      }

      dynamic "transition" {
        for_each = tolist(lookup(rule.value, "transitions", []))
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = tolist(lookup(rule.value, "expiration", []))
        content {
          days = expiration.value.days
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = tolist(lookup(rule.value, "noncurrent_version_transitions", []))
        content {
          noncurrent_days = noncurrent_version_transition.value.noncurrent_days
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = tolist(lookup(rule.value, "noncurrent_version_expiration", []))
        content {
          noncurrent_days = noncurrent_version_expiration.value.noncurrent_days
        }
      }
    }
  }
}
