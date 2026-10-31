resource "aws_sfn_state_machine" "image_pipeline" {
  name     = "${var.project_name}-orchestrator"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = templatefile("${path.module}/../step_functions/image_processing_workflow.asl.json", {
    ValidateLambdaArn     = aws_lambda_function.validator.arn
    ResizeLambdaArn       = aws_lambda_function.resizer.arn
    WatermarkLambdaArn    = aws_lambda_function.watermark.arn
    MetadataLambdaArn     = aws_lambda_function.metadata.arn
    NotificationLambdaArn = aws_lambda_function.notifier.arn
  })

  logging_configuration {
    level                  = "ALL"
    include_execution_data = true
    log_destination        = "${aws_cloudwatch_log_group.step_functions_logs.arn}:*"
  }
}

resource "aws_cloudwatch_log_group" "step_functions_logs" {
  name              = "/aws/vendedlogs/states/${var.project_name}-orchestrator"
  retention_in_days = 14
}
