# Crypto Portfolio Tracker — Setup Guide

## Folder layout

```
crypto-tracker/
  terraform/          <- infrastructure (edit variables.tf / terraform.tfvars only)
  lambda/
    poller/handler.py       <- fetches prices, computes value/P&L/drift, alerts
    api_handler/handler.py  <- serves GET /current and GET /history
    logger/handler.py       <- SNS subscriber #2, logs every alert
```

## One-time setup

1. Start your AWS Academy Learner Lab and click "AWS Details" to get your
   temporary credentials.

2. In your terminal (VS Code terminal is fine), export them:
   ```
   export AWS_ACCESS_KEY_ID="..."
   export AWS_SECRET_ACCESS_KEY="..."
   export AWS_SESSION_TOKEN="..."
   ```
   These expire when the Lab session ends — you'll re-export them each
   time you restart the Lab.

3. Find your Lab's IAM role ARN: AWS Console → IAM → Roles → `LabRole` →
   copy the ARN.

4. Install Terraform if you haven't: https://developer.hashicorp.com/terraform/install

5. Copy the example config and fill it in:
   ```
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   ```
   Edit `terraform.tfvars` — paste in your `lab_role_arn`, your real
   email for `alert_email`, and your actual coin holdings.

## Deploy

```
cd terraform
terraform init
terraform plan     # review what it's about to create
terraform apply    # type "yes" to confirm
```

After it finishes, note the `api_base_url` output.

**Important:** check your email and click the SNS subscription
confirmation link, or alerts will silently never arrive.

## Test it

Manually invoke the poller once (don't wait for the schedule):
```
aws lambda invoke --function-name crypto-tracker-poller /tmp/out.json
cat /tmp/out.json
```

Then hit the API:
```
curl https://<api_base_url>/current
curl https://<api_base_url>/history
```

## Pause / resume polling

Each poll is nearly free, but to avoid burning Lab session time or
letting it run unattended, you can pause the schedule between work
sessions without tearing anything down:

**Pause** (stops new data collection, keeps everything else intact):
```
aws events disable-rule --name crypto-tracker-poll-schedule
```

**Resume** (next time you start a Lab session and want fresh data):
```
aws events enable-rule --name crypto-tracker-poll-schedule
```

Check current status any time:
```
aws events describe-rule --name crypto-tracker-poll-schedule
```
Look for `"State": "ENABLED"` or `"State": "DISABLED"`.

Your DynamoDB data is never affected by pausing — `/current` and
`/history` keep returning whatever was already collected.

## Tear down (do this before your Lab session ends, to stay tidy)

```
terraform destroy
```

## Notes

- No new IAM roles are created — everything reuses `LabRole`, per
  Learner Lab restrictions.
- `coingecko_api_key` can be left blank; CoinGecko's public endpoint
  works without a key at this project's polling volume, just rate-limited.
- Each Lambda's code and its dependencies live in its own folder under
  `lambda/`; Terraform zips them automatically on `apply` — you never
  build the zip yourself.