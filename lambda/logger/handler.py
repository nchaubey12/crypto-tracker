"""
Logger Lambda - the second SNS subscriber (the first is your email).
Every alert that fires gets written here too, both to CloudWatch Logs
(automatic, just via print) and to a dedicated alerts_log DynamoDB table
so you have a queryable audit trail of every alert ever fired.
"""

import json
import os
from datetime import datetime, timezone

import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["ALERTS_TABLE"])
PORTFOLIO_ID = "default"


def lambda_handler(event, context):
    for record in event["Records"]:
        message = record["Sns"]["Message"]
        print(f"ALERT RECEIVED: {message}")  # shows up in CloudWatch Logs

        table.put_item(
            Item={
                "portfolio_id": PORTFOLIO_ID,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "message": message,
            }
        )

    return {"statusCode": 200, "body": json.dumps({"logged": len(event["Records"])})}
