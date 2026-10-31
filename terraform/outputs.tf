output "source_bucket_name" {
  description = "Name of the source S3 bucket where raw images are uploaded."
  value       = aws_s3_bucket.source.id
}

output "destination_bucket_name" {
  description = "Name of the destination S3 bucket where processed images are stored."
  value       = aws_s3_bucket.destination.id
}

output "sqs_queue_url" {
  description = "URL of the main image processing SQS queue."
  value       = aws_sqs_queue.image_processing_queue.id
}

output "sqs_dlq_url" {
  description = "URL of the SQS Dead-Letter Queue (DLQ)."
  value       = aws_sqs_queue.image_processing_dlq.id
}

output "step_functions_state_machine_arn" {
  description = "ARN of the AWS Step Functions Orchestration State Machine."
  value       = aws_sfn_state_machine.image_pipeline.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table storing image processing metadata."
  value       = aws_dynamodb_table.image_metadata.name
}

output "api_gateway_upload_endpoint" {
  description = "REST API Gateway endpoint to generate S3 pre-signed upload URLs."
  value       = "${aws_api_gateway_stage.prod.invoke_url}/upload-url"
}

output "cloudfront_domain_name" {
  description = "CloudFront global CDN distribution domain name for fast content delivery."
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "sns_topic_arn" {
  description = "ARN of the Amazon SNS topic for workflow notifications."
  value       = aws_sns_topic.image_notifications.arn
}
