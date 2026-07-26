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

# portfolio_holdings used to live here as a static SSM parameter. It now
# lives in DynamoDB (see terraform/dynamodb.tf: portfolio_config) so the UI
# can edit it at runtime via PUT /portfolio - SSM values are Terraform-only,
# there's no API for a Lambda to safely let end users write to them.
