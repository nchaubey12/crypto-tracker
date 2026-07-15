"""
Poller Lambda.

Runs on a schedule (see EventBridge in terraform/eventbridge.tf).
1. Reads config (holdings, threshold, api key) from SSM Parameter Store.
2. Calls the CoinGecko API for current prices.
3. Computes: total portfolio value, per-coin profit/loss, allocation drift.
4. Writes a row to DynamoDB (portfolio_history table).
5. If value swung beyond the threshold since the last poll, publishes to SNS.
"""

import json
import os
import urllib.request
import urllib.parse
from datetime import datetime, timezone
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key

ssm = boto3.client("ssm")
dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")

SSM_PREFIX = os.environ["SSM_PREFIX"]
HISTORY_TABLE = os.environ["HISTORY_TABLE"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
PORTFOLIO_ID = "default"  # single-portfolio project; extend to multiple later if needed

COINGECKO_URL = "https://api.coingecko.com/api/v3/simple/price"


def to_decimal(obj):
    """DynamoDB's SDK rejects native Python floats - it only accepts
    Decimal. This walks a dict/list/number and converts floats recursively,
    via str() first to avoid binary float precision noise (e.g. 60000.1
    becoming 60000.099999...)."""
    if isinstance(obj, float):
        return Decimal(str(obj))
    if isinstance(obj, dict):
        return {k: to_decimal(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [to_decimal(v) for v in obj]
    return obj


def get_ssm_param(name, decrypt=False):
    resp = ssm.get_parameter(Name=f"{SSM_PREFIX}/{name}", WithDecryption=decrypt)
    return resp["Parameter"]["Value"]


def fetch_prices(coin_ids, api_key):
    params = {
        "ids": ",".join(coin_ids),
        "vs_currencies": "usd",
    }
    url = f"{COINGECKO_URL}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url)
    if api_key and api_key != "unset":
        req.add_header("x-cg-demo-api-key", api_key)

    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode())


def get_last_snapshot(table):
    """Most recent row for this portfolio, if any."""
    resp = table.query(
        KeyConditionExpression=Key("portfolio_id").eq(PORTFOLIO_ID),
        ScanIndexForward=False,  # newest first
        Limit=1,
    )
    items = resp.get("Items", [])
    return items[0] if items else None


def lambda_handler(event, context):
    holdings = json.loads(get_ssm_param("portfolio_holdings"))
    threshold_pct = float(get_ssm_param("swing_alert_threshold_pct"))
    api_key = get_ssm_param("coingecko_api_key", decrypt=True)

    coin_ids = list(holdings.keys())
    prices = fetch_prices(coin_ids, api_key)

    # --- enrichment: turn raw prices into portfolio value + P&L + drift ---
    breakdown = {}
    total_value = 0.0
    for coin, info in holdings.items():
        price = prices.get(coin, {}).get("usd", 0)
        value = price * info["quantity"]
        breakdown[coin] = {
            "price_usd": price,
            "quantity": info["quantity"],
            "value_usd": round(value, 2),
            "target_weight_pct": info["target_weight_pct"],
        }
        total_value += value

    for coin, data in breakdown.items():
        actual_weight = (data["value_usd"] / total_value * 100) if total_value else 0
        data["actual_weight_pct"] = round(actual_weight, 2)
        data["allocation_drift_pct"] = round(actual_weight - data["target_weight_pct"], 2)

    table = dynamodb.Table(HISTORY_TABLE)
    last_snapshot = get_last_snapshot(table)

    timestamp = datetime.now(timezone.utc).isoformat()
    item = {
        "portfolio_id": PORTFOLIO_ID,
        "timestamp": timestamp,
        "total_value_usd": round(total_value, 2),
        "breakdown": breakdown,
    }
    table.put_item(Item=to_decimal(item))

    # --- swing alert ---
    if last_snapshot:
        prev_value = float(last_snapshot["total_value_usd"])
        if prev_value > 0:
            pct_change = abs(total_value - prev_value) / prev_value * 100
            if pct_change >= threshold_pct:
                message = (
                    f"Portfolio value swung {pct_change:.2f}% "
                    f"(from ${prev_value:.2f} to ${total_value:.2f})"
                )
                sns.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Subject="Portfolio value swing alert",
                    Message=message,
                )

    return {"statusCode": 200, "body": json.dumps(item)}