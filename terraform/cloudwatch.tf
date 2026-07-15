# -----------------------------------------------------------------------------
# CloudWatch: "the health monitor". Alarms if a Lambda errors or runs too
# long, plus a simple dashboard.
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "poller_errors" {
  alarm_name          = "${var.project_name}-poller-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  dimensions = {
    FunctionName = aws_lambda_function.poller.function_name
  }
  alarm_description = "Poller Lambda threw an error"
}

resource "aws_cloudwatch_metric_alarm" "poller_duration" {
  alarm_name          = "${var.project_name}-poller-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Maximum"
  threshold           = 25000 # ms, close to the 30s timeout
  dimensions = {
    FunctionName = aws_lambda_function.poller.function_name
  }
  alarm_description = "Poller Lambda is running close to its timeout"
}

resource "aws_cloudwatch_dashboard" "portfolio" {
  dashboard_name = "${var.project_name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Errors"
          region = var.aws_region
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.poller.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.api_handler.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.logger.function_name],
          ]
        }
      }
    ]
  })
}
