# -----------------------------------------------------------------------------
# DynamoDB: "the memory". portfolio_history stores one row per poll
# (partition key = portfolio_id, sort key = timestamp) so we can query
# "give me everything between date X and Y" cheaply. alerts_log stores
# every swing alert that fired.
# -----------------------------------------------------------------------------

resource "aws_dynamodb_table" "portfolio_history" {
  name         = "${var.project_name}-portfolio-history"
  billing_mode = "PAY_PER_REQUEST" # no capacity to guess, free-tier friendly

  hash_key  = "portfolio_id"
  range_key = "timestamp"

  attribute {
    name = "portfolio_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S" # ISO-8601 string, e.g. 2026-07-12T14:00:00Z - sorts correctly as text
  }
}

resource "aws_dynamodb_table" "alerts_log" {
  name         = "${var.project_name}-alerts-log"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "portfolio_id"
  range_key = "timestamp"

  attribute {
    name = "portfolio_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }
}
