# -----------------------------------------------------------------------------
# SSM Parameter Store: this is the "safe box" the person on the call asked
# about. Config and secrets live here, not hardcoded in Lambda code. Lambda
# reads these at runtime using the AWS SDK - never exposed to a frontend
# because there is no frontend, only the Lambdas (via LabRole) can read them.
# -----------------------------------------------------------------------------

resource "aws_ssm_parameter" "coingecko_api_key" {
  name  = "/${var.project_name}/coingecko_api_key"
  type  = "SecureString"
  value = var.coingecko_api_key == "" ? "unset" : var.coingecko_api_key
}

resource "aws_ssm_parameter" "swing_alert_threshold_pct" {
  name  = "/${var.project_name}/swing_alert_threshold_pct"
  type  = "String"
  value = tostring(var.swing_alert_threshold_pct)
}

resource "aws_ssm_parameter" "portfolio_holdings" {
  name  = "/${var.project_name}/portfolio_holdings"
  type  = "String"
  value = jsonencode(var.portfolio_holdings)
}
