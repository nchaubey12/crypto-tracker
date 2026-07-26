# -----------------------------------------------------------------------------
# API Gateway: "the vending machine". HTTP API (cheaper/simpler than REST
# API) with four routes:
#   GET  /current    -> latest portfolio snapshot
#   GET  /history     -> time series of past snapshots
#   GET  /portfolio   -> current holdings config (what the poller is using)
#   PUT  /portfolio   -> replace holdings config (what the UI's Save calls)
# All routes are proxied straight to the api_handler Lambda, which looks
# at the path + method to decide what to do (see lambda/api_handler/handler.py).
#
# CORS is open (allow_origins = ["*"]) so the static S3 site in frontend.tf
# can call this from the browser. HTTP APIs handle OPTIONS preflight
# automatically once cors_configuration is set - no separate OPTIONS route
# or Lambda code needed.
#
# No auth is configured here (kept open so it's easy to demo). If you want
# to lock it down later, an API key via SSM is the easiest add without
# creating new IAM resources.
# -----------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "portfolio_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "PUT", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_integration" "api_handler_integration" {
  api_id                 = aws_apigatewayv2_api.portfolio_api.id
  integration_type       = "AWS_PROXY"
  # Routes through the "live" alias (see lambda.tf) instead of the bare
  # function, so blue/green traffic shifting via the alias's weighted
  # routing_config actually takes effect. Pointing this at
  # aws_lambda_function.api_handler.invoke_arn would bypass the alias
  # entirely and always hit $LATEST.
  integration_uri        = aws_lambda_alias.api_handler_live.invoke_arn
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

resource "aws_apigatewayv2_route" "get_portfolio" {
  api_id    = aws_apigatewayv2_api.portfolio_api.id
  route_key = "GET /portfolio"
  target    = "integrations/${aws_apigatewayv2_integration.api_handler_integration.id}"
}

resource "aws_apigatewayv2_route" "put_portfolio" {
  api_id    = aws_apigatewayv2_api.portfolio_api.id
  route_key = "PUT /portfolio"
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
  # Qualifier scopes this permission to the "live" alias specifically,
  # matching the integration_uri above - API Gateway invokes the alias,
  # not the bare function.
  qualifier     = aws_lambda_alias.api_handler_live.name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.portfolio_api.execution_arn}/*/*"
}
