# -----------------------------------------------------------------------------
# EventBridge: "the alarm clock". Fires the poller Lambda on a fixed cadence.
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "poll_schedule" {
  name                = "${var.project_name}-poll-schedule"
  schedule_expression = "rate(${var.poll_rate_minutes} minutes)"
}

resource "aws_cloudwatch_event_target" "poller_target" {
  rule = aws_cloudwatch_event_rule.poll_schedule.name
  arn  = aws_lambda_function.poller.arn
}

resource "aws_lambda_permission" "allow_eventbridge_invoke_poller" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.poller.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.poll_schedule.arn
}
