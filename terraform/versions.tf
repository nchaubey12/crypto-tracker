terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# AWS Academy Learner Lab gives you temporary credentials each time you
# "Start Lab". Easiest path: export them as environment variables in your
# terminal before running terraform, e.g.
#
#   export AWS_ACCESS_KEY_ID="..."
#   export AWS_SECRET_ACCESS_KEY="..."
#   export AWS_SESSION_TOKEN="..."
#
# Terraform's AWS provider picks these up automatically — nothing to hardcode.
provider "aws" {
  region = var.aws_region
}
