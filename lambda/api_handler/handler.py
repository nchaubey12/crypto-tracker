"""
API handler Lambda, sits behind API Gateway.

Routes (already baked in, nothing dynamic to type each time):
  GET /current  -> most recent portfolio snapshot
  GET /history  -> all snapshots (optionally ?limit=N)
"""

import json
import os

import boto3
from boto3.dynamodb.conditions import Key
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["HISTORY_TABLE"])
PORTFOLIO_ID = "default"


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


def lambda_handler(event, context):
    path = event.get("rawPath", "")
    query_params = event.get("queryStringParameters") or {}

    if path.endswith("/current"):
        return get_current()
    elif path.endswith("/history"):
        return get_history(query_params)
    else:
        return respond(404, {"error": f"Unknown route: {path}"})
