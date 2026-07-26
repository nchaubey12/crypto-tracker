output "api_base_url" {
  description = "Base URL of your API - append /current, /history, or /portfolio"
  value       = aws_apigatewayv2_api.portfolio_api.api_endpoint
}

output "frontend_url" {
  description = "Open this in a browser to view/edit your portfolio"
  value       = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "portfolio_config_table" {
  value = aws_dynamodb_table.portfolio_config.name
}

output "portfolio_history_table" {
  value = aws_dynamodb_table.portfolio_history.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.portfolio_alerts.arn
}

output "api_handler_latest_version" {
  description = "Version number this apply just published for api_handler - use as live_version on the next apply to complete a rollout cutover"
  value       = aws_lambda_function.api_handler.version
}

output "api_handler_live_alias_arn" {
  description = "ARN of the api_handler_live alias that API Gateway invokes"
  value       = aws_lambda_alias.api_handler_live.invoke_arn
}
