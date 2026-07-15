# -----------------------------------------------------------------------------
# SNS: "the alert system". One topic, two subscribers - your email, and the
# logger Lambda. This is the fan-out.
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "portfolio_alerts" {
  name = "${var.project_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.portfolio_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
  # NOTE: AWS emails you a confirmation link after `terraform apply`.
  # You must click it once, manually, or you will not receive alerts.
}

resource "aws_sns_topic_subscription" "logger_lambda" {
  topic_arn = aws_sns_topic.portfolio_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.logger.arn
}

resource "aws_lambda_permission" "allow_sns_invoke_logger" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.logger.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.portfolio_alerts.arn
}
