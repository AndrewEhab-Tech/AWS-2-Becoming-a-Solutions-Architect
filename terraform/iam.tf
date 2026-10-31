# Assume Role Policy for AWS Lambda
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ==========================================
# 1. Presign Lambda Role
# ==========================================
resource "aws_iam_role" "presign_lambda_role" {
  name               = "${var.project_name}-presign-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "presign_basic" {
  role       = aws_iam_role.presign_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "presign_s3_policy" {
  name = "PresignS3PutObjectPolicy"
  role = aws_iam_role.presign_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.source.arn}/*"
      }
    ]
  })
}

# ==========================================
# 2. SQS Consumer Lambda Role
# ==========================================
resource "aws_iam_role" "sqs_consumer_role" {
  name               = "${var.project_name}-sqs-consumer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "sqs_consumer_basic" {
  role       = aws_iam_role.sqs_consumer_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "sqs_consumer_policy" {
  name = "SQSConsumerAndStepFunctionsPolicy"
  role = aws_iam_role.sqs_consumer_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.image_processing_queue.arn
      },
      {
        Effect   = "Allow"
        Action   = ["states:StartExecution"]
        Resource = aws_sfn_state_machine.image_pipeline.arn
      }
    ]
  })
}

# ==========================================
# 3. Processing Lambdas Role (Worker Lambdas)
# ==========================================
resource "aws_iam_role" "worker_lambda_role" {
  name               = "${var.project_name}-worker-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "worker_basic" {
  role       = aws_iam_role.worker_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "worker_pipeline_policy" {
  name = "WorkerPipelinePermissionsPolicy"
  role = aws_iam_role.worker_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:HeadObject"
        ]
        Resource = "${aws_s3_bucket.source.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:HeadObject"
        ]
        Resource = "${aws_s3_bucket.destination.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          aws_dynamodb_table.image_metadata.arn,
          "${aws_dynamodb_table.image_metadata.arn}/index/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.image_notifications.arn
      }
    ]
  })
}

# ==========================================
# 4. Step Functions State Machine IAM Role
# ==========================================
data "aws_iam_policy_document" "states_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "step_functions_role" {
  name               = "${var.project_name}-stepfunctions-role"
  assume_role_policy = data.aws_iam_policy_document.states_assume_role.json
}

resource "aws_iam_role_policy" "step_functions_policy" {
  name = "StepFunctionsInvokeLambdasPolicy"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.validator.arn,
          aws_lambda_function.resizer.arn,
          aws_lambda_function.watermark.arn,
          aws_lambda_function.metadata.arn,
          aws_lambda_function.notifier.arn
        ]
      }
    ]
  })
}
