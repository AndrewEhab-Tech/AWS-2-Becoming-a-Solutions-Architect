variable "aws_region" {
  description = "The AWS Region where resources will be provisioned."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project identifier name used as a prefix for resources."
  type        = string
  default     = "serverless-image-pipeline"
}

variable "environment" {
  description = "Deployment environment name (dev, staging, prod)."
  type        = string
  default     = "prod"
}

variable "notification_email" {
  description = "Email address to receive SNS pipeline notifications (completion & failure alerts)."
  type        = string
  default     = "student@example.com"
}

variable "watermark_text" {
  description = "Text string to embed as a watermark on processed images."
  type        = string
  default     = "© AWS SAA Graduation Project"
}

variable "pillow_layer_arn" {
  description = "ARN for the Python Pillow Lambda Layer. If empty, Lambda can run standalone or with custom zip."
  type        = string
  # Klayers public Pillow layer for Python 3.11 in us-east-1
  default     = "arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p311-Pillow:4"
}
