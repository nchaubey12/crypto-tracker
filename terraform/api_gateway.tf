# -----------------------------------------------------------------------------
# API Gateway: "the vending machine". HTTP API (cheaper/simpler than REST
# API) with two routes:
#   GET /current  -> latest portfolio snapshot
#   GET /history   -> time series of past snapshots
# Both routes are proxied straight to the api_handler Lambda, which looks
# at the path to decide what to do (see lambda/api_handler/handler.py).
#
# No auth is configured here (kept open so it's easy to demo). If you want
# to lock it down later, an API key via SSM is the easiest add without
# creating new IAM resources.
# -----------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "portfolio_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "api_handler_integration" {
  api_id                 = aws_apigatewayv2_api.portfolio_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_handler.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "current" {
  api_id    = aws_apigatewayv2_api.portfolio_api.id
  route_key = "GET /current"
  target    = "integrations/${aws_apigatewayv2_integration.api_handler_integration.id}"
}

resource "aws_apigatewayv2_route" "history" {
  api_id    = aws_apigatewayv2_api.portfolio_api.id
  route_key = "GET /history"
  target    = "integrations/${aws_apigatewayv2_integration.api_handler_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.portfolio_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw_invoke_handler" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.portfolio_api.execution_arn}/*/*"
}
