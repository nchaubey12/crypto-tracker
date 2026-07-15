output "api_base_url" {
  description = "Base URL of your API - append /current or /history"
  value       = aws_apigatewayv2_api.portfolio_api.api_endpoint
}

output "portfolio_history_table" {
  value = aws_dynamodb_table.portfolio_history.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.portfolio_alerts.arn
}
