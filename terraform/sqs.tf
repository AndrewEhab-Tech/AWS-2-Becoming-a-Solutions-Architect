# ==========================================
# SQS Dead-Letter Queue (DLQ)
# ==========================================
resource "aws_sqs_queue" "image_processing_dlq" {
  name                      = "${var.project_name}-dlq"
  message_retention_seconds = 1209600 # 14 days retention
  sqs_managed_sse_enabled   = true
}

# ==========================================
# Main Image Processing SQS Queue
# ==========================================
resource "aws_sqs_queue" "image_processing_queue" {
  name                       = "${var.project_name}-queue"
  visibility_timeout_seconds = 360 # 6x Lambda timeout (60s)
  message_retention_seconds  = 86400 # 1 day
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.image_processing_dlq.arn
    maxReceiveCount     = 3
  })
}

# SQS Queue Policy allowing Source S3 bucket to send messages
resource "aws_sqs_queue_policy" "image_processing_queue_policy" {
  queue_url = aws_sqs_queue.image_processing_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3ToPublishMessages"
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.image_processing_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.source.arn
          }
        }
      }
    ]
  })
}
