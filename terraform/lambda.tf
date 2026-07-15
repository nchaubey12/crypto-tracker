# -----------------------------------------------------------------------------
# Lambda: "the brain". Three functions, all reusing the Lab's existing
# LabRole (no new IAM resources - Learner Lab blocks that).
#
# Each function's code is zipped up automatically from the /lambda folder
# by the archive_file data source below - you never build the zip by hand.
# -----------------------------------------------------------------------------

data "archive_file" "poller_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/poller"
  output_path = "${path.module}/build/poller.zip"
}

data "archive_file" "api_handler_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/api_handler"
  output_path = "${path.module}/build/api_handler.zip"
}

data "archive_file" "logger_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/logger"
  output_path = "${path.module}/build/logger.zip"
}

resource "aws_lambda_function" "poller" {
  function_name    = "${var.project_name}-poller"
  role             = var.lab_role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.poller_zip.output_path
  source_code_hash = data.archive_file.poller_zip.output_base64sha256

  environment {
    variables = {
      PROJECT_NAME      = var.project_name
      HISTORY_TABLE     = aws_dynamodb_table.portfolio_history.name
      ALERTS_TABLE      = aws_dynamodb_table.alerts_log.name
      SNS_TOPIC_ARN     = aws_sns_topic.portfolio_alerts.arn
      SSM_PREFIX        = "/${var.project_name}"
    }
  }
}

resource "aws_lambda_function" "api_handler" {
  function_name    = "${var.project_name}-api-handler"
  role             = var.lab_role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 15
  filename         = data.archive_file.api_handler_zip.output_path
  source_code_hash = data.archive_file.api_handler_zip.output_base64sha256

  environment {
    variables = {
      HISTORY_TABLE = aws_dynamodb_table.portfolio_history.name
    }
  }
}

resource "aws_lambda_function" "logger" {
  function_name    = "${var.project_name}-logger"
  role             = var.lab_role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10
  filename         = data.archive_file.logger_zip.output_path
  source_code_hash = data.archive_file.logger_zip.output_base64sha256

  environment {
    variables = {
      ALERTS_TABLE = aws_dynamodb_table.alerts_log.name
    }
  }
}
