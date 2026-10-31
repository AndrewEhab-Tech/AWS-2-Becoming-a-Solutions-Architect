resource "aws_sns_topic" "image_notifications" {
  name = "${var.project_name}-notifications"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.image_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
