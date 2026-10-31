# ==========================================
# Packaging Lambda Function Sources
# ==========================================
data "archive_file" "presign_zip" {
  type        = "zip"
  source_file = "${path.module}/../src/presign_handler/app.py"
  output_path = "${path.module}/dist/presign.zip"
}

data "archive_file" "sqs_consumer_zip" {
  type        = "zip"
  source_file = "${path.module}/../src/sqs_consumer/app.py"
  output_path = "${path.module}/dist/sqs_consumer.zip"
}

data "archive_file" "validator_zip" {
  type        = "zip"
  source_file = "${path.module}/../src/workflow_validator/app.py"
  output_path = "${path.module}/dist/validator.zip"
}

data "archive_file" "resizer_zip" {
  type        = "zip"
  source_file = "${path.module}/../src/image_resizer/app.py"
  output_path = "${path.module}/dist/resizer.zip"
}

data "archive_file" "watermark_zip" {
  type        = "zip"
  source_file = "${path.module}/../src/watermark_processor/app.py"
  output_path = "${path.module}/dist/watermark.zip"
}

data "archive_file" "metadata_zip" {
  type        = "zip"
  source_file = "${path.module}/../src/metadata_extractor/app.py"
  output_path = "${path.module}/dist/metadata.zip"
}

data "archive_file" "notifier_zip" {
  type        = "zip"
  source_file = "${path.module}/../src/notification_handler/app.py"
  output_path = "${path.module}/dist/notifier.zip"
}

# ==========================================
# 1. Pre-Signed URL Generator Lambda
# ==========================================
resource "aws_lambda_function" "presign" {
  function_name    = "${var.project_name}-presign-handler"
  role             = aws_iam_role.presign_lambda_role.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.presign_zip.output_path
  source_code_hash = data.archive_file.presign_zip.output_base64sha256
  timeout          = 15
  memory_size      = 256

  environment {
    variables = {
      SOURCE_BUCKET_NAME     = aws_s3_bucket.source.id
      URL_EXPIRATION_SECONDS = "300"
    }
  }
}

# ==========================================
# 2. SQS Consumer Lambda (Event Trigger)
# ==========================================
resource "aws_lambda_function" "sqs_consumer" {
  function_name    = "${var.project_name}-sqs-consumer"
  role             = aws_iam_role.sqs_consumer_role.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.sqs_consumer_zip.output_path
  source_code_hash = data.archive_file.sqs_consumer_zip.output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.image_pipeline.arn
    }
  }
}

# SQS Trigger Event Source Mapping
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn                   = aws_sqs_queue.image_processing_queue.arn
  function_name                      = aws_lambda_function.sqs_consumer.arn
  batch_size                         = 5
  maximum_batching_window_in_seconds = 10
  function_response_types            = ["ReportBatchItemFailures"]
}

# ==========================================
# 3. Workflow Step: Validator Lambda
# ==========================================
resource "aws_lambda_function" "validator" {
  function_name    = "${var.project_name}-step-validator"
  role             = aws_iam_role.worker_lambda_role.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.validator_zip.output_path
  source_code_hash = data.archive_file.validator_zip.output_base64sha256
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      MAX_FILE_SIZE_BYTES = "15728640" # 15 MB
    }
  }
}

# ==========================================
# 4. Workflow Step: Image Resizer Lambda
# ==========================================
resource "aws_lambda_function" "resizer" {
  function_name    = "${var.project_name}-step-resizer"
  role             = aws_iam_role.worker_lambda_role.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.resizer_zip.output_path
  source_code_hash = data.archive_file.resizer_zip.output_base64sha256
  timeout          = 90
  memory_size      = 1024 # Extra memory for faster image processing vCPUs
  layers           = var.pillow_layer_arn != "" ? [var.pillow_layer_arn] : []

  environment {
    variables = {
      DESTINATION_BUCKET_NAME = aws_s3_bucket.destination.id
    }
  }
}

# ==========================================
# 5. Workflow Step: Watermark Lambda
# ==========================================
resource "aws_lambda_function" "watermark" {
  function_name    = "${var.project_name}-step-watermark"
  role             = aws_iam_role.worker_lambda_role.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.watermark_zip.output_path
  source_code_hash = data.archive_file.watermark_zip.output_base64sha256
  timeout          = 60
  memory_size      = 512
  layers           = var.pillow_layer_arn != "" ? [var.pillow_layer_arn] : []

  environment {
    variables = {
      DESTINATION_BUCKET_NAME = aws_s3_bucket.destination.id
      WATERMARK_TEXT          = var.watermark_text
    }
  }
}

# ==========================================
# 6. Workflow Step: Metadata Extractor Lambda
# ==========================================
resource "aws_lambda_function" "metadata" {
  function_name    = "${var.project_name}-step-metadata"
  role             = aws_iam_role.worker_lambda_role.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.metadata_zip.output_path
  source_code_hash = data.archive_file.metadata_zip.output_base64sha256
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      METADATA_TABLE_NAME = aws_dynamodb_table.image_metadata.name
      CLOUDFRONT_DOMAIN   = aws_cloudfront_distribution.cdn.domain_name
    }
  }
}

# ==========================================
# 7. Workflow Step: Notification Lambda
# ==========================================
resource "aws_lambda_function" "notifier" {
  function_name    = "${var.project_name}-step-notifier"
  role             = aws_iam_role.worker_lambda_role.arn
  handler          = "app.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.notifier_zip.output_path
  source_code_hash = data.archive_file.notifier_zip.output_base64sha256
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.image_notifications.arn
    }
  }
}
