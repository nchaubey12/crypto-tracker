"""
API handler Lambda, sits behind API Gateway.

Routes:
  GET  /current    -> most recent portfolio snapshot
  GET  /history     -> all snapshots (optionally ?limit=N)
  GET  /portfolio   -> current holdings config (ticker -> quantity, target_weight_pct)
  PUT  /portfolio   -> replace holdings config; body: {"holdings": {...}}
"""

import json
import os
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation

import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["HISTORY_TABLE"])
config_table = dynamodb.Table(os.environ["CONFIG_TABLE"])
PORTFOLIO_ID = "default"

MAX_HOLDINGS = 25  # sanity cap - this is a demo project, not a fund


def decimal_default(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError


def respond(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, default=decimal_default),
    }


def get_current():
    resp = table.query(
        KeyConditionExpression=Key("portfolio_id").eq(PORTFOLIO_ID),
        ScanIndexForward=False,
        Limit=1,
    )
    items = resp.get("Items", [])
    if not items:
        return respond(404, {"error": "No data yet - has the poller run at least once?"})
    return respond(200, items[0])


def get_history(query_params):
    limit = int(query_params.get("limit", 100)) if query_params else 100
    resp = table.query(
        KeyConditionExpression=Key("portfolio_id").eq(PORTFOLIO_ID),
        ScanIndexForward=True,
        Limit=limit,
    )
    return respond(200, {"count": len(resp["Items"]), "items": resp["Items"]})


def get_portfolio():
    resp = config_table.get_item(Key={"portfolio_id": PORTFOLIO_ID})
    item = resp.get("Item")
    if not item:
        return respond(404, {"error": "No portfolio config found"})
    holdings = json.loads(item["holdings"]) if isinstance(item["holdings"], str) else item["holdings"]
    return respond(200, {"holdings": holdings, "updated_at": item.get("updated_at")})


def validate_holdings(holdings):
    """Returns an error string, or None if the payload is well-formed."""
    if not isinstance(holdings, dict) or not holdings:
        return "holdings must be a non-empty object of { coin_id: {quantity, target_weight_pct} }"
    if len(holdings) > MAX_HOLDINGS:
        return f"too many holdings (max {MAX_HOLDINGS})"

    weight_total = 0
    for coin_id, info in holdings.items():
        if not isinstance(coin_id, str) or not coin_id.strip():
            return "each coin id must be a non-empty string (use CoinGecko ids, e.g. 'bitcoin')"
        if not isinstance(info, dict):
            return f"holdings['{coin_id}'] must be an object with quantity and target_weight_pct"

        try:
            quantity = Decimal(str(info.get("quantity", "")))
            weight = Decimal(str(info.get("target_weight_pct", "")))
        except (InvalidOperation, TypeError):
            return f"holdings['{coin_id}'].quantity and .target_weight_pct must be numbers"

        if quantity <= 0:
            return f"holdings['{coin_id}'].quantity must be greater than 0"
        if weight < 0 or weight > 100:
            return f"holdings['{coin_id}'].target_weight_pct must be between 0 and 100"
        weight_total += weight

    # Soft check, not a hard rejection - target weights are a guideline for
    # drift calculations, not an accounting requirement, but > 1% off 100
    # almost always means a typo.
    if abs(weight_total - 100) > 1:
        return f"target_weight_pct values sum to {weight_total}, expected ~100"

    return None


def put_portfolio(raw_body):
    try:
        body = json.loads(raw_body) if raw_body else {}
    except json.JSONDecodeError:
        return respond(400, {"error": "body must be valid JSON"})

    holdings = body.get("holdings")
    error = validate_holdings(holdings)
    if error:
        return respond(400, {"error": error})

    # Normalize to plain numbers -> Decimal for DynamoDB storage.
    clean_holdings = {
        coin_id: {
            "quantity": Decimal(str(info["quantity"])),
            "target_weight_pct": Decimal(str(info["target_weight_pct"])),
        }
        for coin_id, info in holdings.items()
    }

    config_table.put_item(
        Item={
            "portfolio_id": PORTFOLIO_ID,
            "holdings": json.dumps({k: {kk: float(vv) for kk, vv in v.items()} for k, v in clean_holdings.items()}),
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
    )
    return respond(200, {"message": "Portfolio updated. It'll be reflected on the next poll.", "holdings": holdings})


def lambda_handler(event, context):
    path = event.get("rawPath", "")
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    query_params = event.get("queryStringParameters") or {}

    if path.endswith("/current") and method == "GET":
        return get_current()
    elif path.endswith("/history") and method == "GET":
        return get_history(query_params)
    elif path.endswith("/portfolio") and method == "GET":
        return get_portfolio()
    elif path.endswith("/portfolio") and method == "PUT":
        return put_portfolio(event.get("body"))
    else:
        return respond(404, {"error": f"Unknown route: {method} {path}"})
