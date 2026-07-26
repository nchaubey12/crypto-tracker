# -----------------------------------------------------------------------------
# Frontend: a single static HTML/CSS/JS page (no build step, no framework)
# that lets you view + edit your portfolio in a browser instead of editing
# terraform.tfvars and re-applying. Served straight from S3's built-in
# static website hosting - no CloudFront, no EC2, no VPC.
#
# The API's base URL isn't known until after `terraform apply` creates it,
# so index.html is a template: templatefile() below bakes the real
# aws_apigatewayv2_api URL into the page at upload time, so the browser
# knows where to call without you hand-editing anything.
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "frontend" {
  bucket        = "${var.project_name}-ui-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # so `terraform destroy` doesn't get stuck on a non-empty bucket
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "index.html" # this is a single-page app; let it handle its own "not found" state
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false # we need a bucket policy (not ACLs) to allow public GET
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend_public_read" {
  bucket     = aws_s3_bucket.frontend.id
  depends_on = [aws_s3_bucket_public_access_block.frontend]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
    }]
  })
}

resource "aws_s3_object" "frontend_index" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  content_type = "text/html"
  content = templatefile("${path.module}/../frontend/index.html.tftpl", {
    api_base_url = aws_apigatewayv2_api.portfolio_api.api_endpoint
  })
  etag = md5(templatefile("${path.module}/../frontend/index.html.tftpl", {
    api_base_url = aws_apigatewayv2_api.portfolio_api.api_endpoint
  }))
}
