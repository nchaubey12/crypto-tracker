# Crypto Portfolio Tracker — Setup Guide

## Folder layout

```
crypto-tracker/
  terraform/          <- infrastructure (edit variables.tf / terraform.tfvars only)
  lambda/
    poller/handler.py       <- fetches prices, computes value/P&L/drift, alerts
    api_handler/handler.py  <- serves /current, /history, /portfolio (GET+PUT)
    logger/handler.py       <- SNS subscriber #2, logs every alert
  frontend/
    index.html.tftpl        <- single-page UI (edit portfolio, view analysis)
                                Terraform bakes the API URL in and uploads it
                                to S3 on every apply - you never edit this by
                                hand unless you're changing the UI itself.
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

After it finishes, note the `api_base_url` and `frontend_url` outputs.

**Important:** check your email and click the SNS subscription
confirmation link, or alerts will silently never arrive.

## Editing your portfolio

Open the `frontend_url` output in a browser. That page lets you add,
remove, or adjust coins and quantities without touching Terraform or
redeploying — it calls `PUT /portfolio`, which writes straight to the
`portfolio_config` DynamoDB table. The poller reads that table on its
*next* scheduled run (or the next manual invoke), so changes show up
within one poll cycle.

`portfolio_holdings` in `terraform.tfvars` still matters for one thing
only: it's the *starting* portfolio the table is seeded with the first
time you `terraform apply`. After that, edits made through the UI are
the source of truth — re-running `terraform apply` won't overwrite them
(see the `lifecycle.ignore_changes` note on
`aws_dynamodb_table_item.portfolio_config_seed` in `terraform/dynamodb.tf`
if you ever do want to force-reset back to the tfvars default).

## Blue/green deploys of api_handler

`api_handler` (the Lambda behind `GET /current`, `GET /history`,
`GET /portfolio`, `PUT /portfolio`) ships behind a `live` alias with
versioned, weighted traffic shifting instead of a straight `$LATEST` flip.

Every `terraform apply` publishes a new immutable version of `api_handler`.
Two variables in `terraform.tfvars` (or `-var` on the CLI) control the
rollout:

- `live_version` — the version currently serving the "blue" baseline.
- `canary_weight` — fraction (0.0–1.0) of traffic sent to the newest
  published version ("green") while it's being validated.

**Rollout runbook:**
```
# 0. Baseline: canary_weight = 0, 100% on live_version.

# 1. Ship new code
terraform apply                    # publishes v(n+1) automatically

# 2. Canary a slice of traffic
terraform apply -var="canary_weight=0.1"
# watch CloudWatch alarms (error rate / duration), then step up:
terraform apply -var="canary_weight=0.5"
terraform apply -var="canary_weight=1.0"

# 3. Cut over completely, reset the canary
terraform apply -var="live_version=<n+1>" -var="canary_weight=0"
```
The old version stays addressable by number, so rolling back is repointing
`live_version` rather than re-editing and re-zipping code.

## CI

`.github/workflows/terraform-validate.yml` runs `terraform fmt -check`,
`terraform init -backend=false`, and `terraform validate` on every push/PR
that touches `terraform/`. It needs no AWS credentials and catches broken
HCL before anyone touches the Lab.

`terraform plan` / `terraform apply` and stepping `canary_weight` stay
manual on purpose: AWS Academy Learner Lab issues temporary,
session-scoped credentials rather than a long-lived role GitHub Actions
could assume via OIDC, so there's no safe way to automate apply here. In a
real AWS account, apply would become an OIDC-authenticated second stage.

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