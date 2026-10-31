import json
import os
import boto3
import urllib.parse
from datetime import datetime

sfn_client = boto3.client('stepfunctions')
STATE_MACHINE_ARN = os.environ.get('STATE_MACHINE_ARN')

def lambda_handler(event, context):
    """
    Consumes S3 upload notification messages from SQS and
    starts the Step Functions Image Processing Workflow.
    """
    print(f"Received event with {len(event.get('Records', []))} records.")
    failed_message_ids = []

    for record in event.get('Records', []):
        message_id = record.get('messageId')
        try:
            body = json.loads(record.get('body', '{}'))

            # Handle S3 Test Event or direct notifications
            if 'Event' in body and body['Event'] == 's3:TestEvent':
                print("Skipping s3:TestEvent.")
                continue

            # S3 notifications can be direct or wrapped
            s3_records = body.get('Records', [])
            if not s3_records and 's3' in body:
                s3_records = [body]

            for s3_record in s3_records:
                s3_info = s3_record.get('s3', {})
                bucket_name = s3_info.get('bucket', {}).get('name')
                raw_key = s3_info.get('object', {}).get('key', '')
                object_key = urllib.parse.unquote_plus(raw_key)
                file_size = s3_info.get('object', {}).get('size', 0)

                if not bucket_name or not object_key:
                    print(f"Skipping invalid record: {s3_record}")
                    continue

                # Prepare Step Functions payload
                execution_input = {
                    "sourceBucket": bucket_name,
                    "sourceKey": object_key,
                    "fileSize": file_size,
                    "timestamp": datetime.utcnow().isoformat(),
                    "sqsMessageId": message_id
                }

                # Safe execution name (sanitized)
                safe_name = f"proc-{object_key.replace('/', '-').replace('.', '-')[:60]}-{int(datetime.utcnow().timestamp())}"

                response = sfn_client.start_execution(
                    stateMachineArn=STATE_MACHINE_ARN,
                    name=safe_name,
                    input=json.dumps(execution_input)
                )

                print(f"Started Step Function execution: {response['executionArn']} for key: {object_key}")

        except Exception as e:
            print(f"Failed to process SQS message {message_id}: {str(e)}")
            failed_message_ids.append({"itemIdentifier": message_id})

    # Return partial batch failure for SQS retry / DLQ handling
    return {
        "batchItemFailures": failed_message_ids
    }
