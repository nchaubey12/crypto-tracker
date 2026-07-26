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

# -----------------------------------------------------------------------------
# portfolio_config: one item, the user's current holdings (ticker -> quantity
# + target_weight_pct). Both the poller (reads it every 15 min) and the API
# (GET/PUT /portfolio) hit this table so an edit in the UI takes effect on
# the very next poll - no redeploy needed.
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "portfolio_config" {
  name         = "${var.project_name}-portfolio-config"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "portfolio_id"

  attribute {
    name = "portfolio_id"
    type = "S"
  }
}

# Seed the table with terraform.tfvars' portfolio_holdings so there's
# something to poll on day one. lifecycle.ignore_changes means later PUT
# /portfolio edits (made through the UI, not Terraform) survive future
# `terraform apply` runs instead of being overwritten back to this default.
resource "aws_dynamodb_table_item" "portfolio_config_seed" {
  table_name = aws_dynamodb_table.portfolio_config.name
  hash_key   = aws_dynamodb_table.portfolio_config.hash_key

  item = jsonencode({
    portfolio_id = { S = "default" }
    holdings     = { S = jsonencode(var.portfolio_holdings) }
    updated_at   = { S = "seed" }
  })

  lifecycle {
    ignore_changes = [item]
  }
}
