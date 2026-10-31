# ==========================================
# 1. Source Bucket (Uploads Landing Zone)
# ==========================================
resource "aws_s3_bucket" "source" {
  bucket        = "${var.project_name}-source-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "source" {
  bucket = aws_s3_bucket.source.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "source" {
  bucket                  = aws_s3_bucket.source.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 CORS configuration to allow direct browser uploads via pre-signed URL
resource "aws_s3_bucket_cors_configuration" "source" {
  bucket = aws_s3_bucket.source.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# S3 Lifecycle policy to optimize storage costs (Well-Architected Cost Optimization)
resource "aws_s3_bucket_lifecycle_configuration" "source" {
  bucket = aws_s3_bucket.source.id

  rule {
    id     = "archive-and-expire-raw-uploads"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }
}

# ==========================================
# 2. Destination Bucket (Processed Images)
# ==========================================
resource "aws_s3_bucket" "destination" {
  bucket        = "${var.project_name}-destination-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "destination" {
  bucket = aws_s3_bucket.destination.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "destination" {
  bucket                  = aws_s3_bucket.destination.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "destination" {
  bucket = aws_s3_bucket.destination.id

  rule {
    id     = "transition-processed-images"
    status = "Enabled"

    filter {
      prefix = "processed/"
    }

    transition {
      days          = 60
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}

# S3 Event Notification to SQS Queue upon ObjectCreated
resource "aws_s3_bucket_notification" "source_notification" {
  bucket = aws_s3_bucket.source.id

  queue {
    queue_arn     = aws_sqs_queue.image_processing_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }

  depends_on = [aws_sqs_queue_policy.image_processing_queue_policy]
}
