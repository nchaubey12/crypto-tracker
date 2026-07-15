# -----------------------------------------------------------------------------
# THIS IS THE FILE YOU EDIT. Everything else in this folder should just work.
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region (Learner Lab is us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used as a prefix on every resource"
  type        = string
  default     = "crypto-tracker"
}

variable "lab_role_arn" {
  description = <<-EOT
    ARN of the pre-existing Learner Lab role (usually called "LabRole").
    Find it in the AWS Console: IAM > Roles > LabRole > copy the ARN.
    It looks like: arn:aws:iam::123456789012:role/LabRole
    We reuse this instead of creating a new IAM role, since Learner Lab
    blocks IAM resource creation via Terraform.
  EOT
  type        = string
}

variable "alert_email" {
  description = "Email address that receives portfolio swing alerts"
  type        = string
}

variable "poll_rate_minutes" {
  description = "How often the poller Lambda checks prices"
  type        = number
  default     = 15
}

variable "swing_alert_threshold_pct" {
  description = "Trigger an SNS alert if portfolio value moves by more than this % between polls"
  type        = number
  default     = 5
}

variable "coingecko_api_key" {
  description = <<-EOT
    Optional. Leave blank ("") to use CoinGecko's free public endpoint
    (no key required, rate-limited). Only set this if you sign up for
    CoinGecko's Demo API plan and get a key.
  EOT
  type        = string
  default     = ""
  sensitive   = true
}

variable "portfolio_holdings" {
  description = "Your coin holdings: ticker -> {quantity, target_weight_pct}"
  type = map(object({
    quantity          = number
    target_weight_pct = number
  }))
  default = {
    bitcoin = {
      quantity          = 0.05
      target_weight_pct = 60
    }
    ethereum = {
      quantity          = 1.2
      target_weight_pct = 40
    }
  }
}
