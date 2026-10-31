import json
import os
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
METADATA_TABLE_NAME = os.environ.get('METADATA_TABLE_NAME')
CLOUDFRONT_DOMAIN = os.environ.get('CLOUDFRONT_DOMAIN', '')

def lambda_handler(event, context):
    """
    Step 4 in Step Functions: Stores image metadata, dimensions, and
    CloudFront-accessible URLs into Amazon DynamoDB.
    """
    table = dynamodb.Table(METADATA_TABLE_NAME)
    image_id = event['imageId']
    source_key = event['sourceKey']
    variants = event.get('variants', {})

    cf_prefix = f"https://{CLOUDFRONT_DOMAIN}" if CLOUDFRONT_DOMAIN else ""

    processed_variants = {}
    for var_name, var_info in variants.items():
        processed_variants[var_name] = {
            's3Key': var_info['key'],
            'width': var_info['width'],
            'height': var_info['height'],
            'sizeBytes': var_info['sizeBytes'],
            'cdnUrl': f"{cf_prefix}/{var_info['key']}" if cf_prefix else f"s3://{event['destinationBucket']}/{var_info['key']}"
        }

    now_iso = datetime.utcnow().isoformat()

    item = {
        'ImageId': image_id,
        'OriginalKey': source_key,
        'SourceBucket': event['sourceBucket'],
        'DestinationBucket': event['destinationBucket'],
        'OriginalDimensions': event.get('originalDimensions', {}),
        'OriginalSizeBytes': event.get('contentLength', 0),
        'ContentType': event.get('contentType', 'image/jpeg'),
        'Variants': processed_variants,
        'Status': 'COMPLETED',
        'CreatedAt': event.get('timestamp', now_iso),
        'ProcessedAt': now_iso
    }

    print(f"Writing metadata to DynamoDB table {METADATA_TABLE_NAME} for image {image_id}...")
    table.put_item(Item=item)

    return {
        **event,
        "metadataRecord": item,
        "status": "COMPLETED"
    }
