import json
import os
import boto3

s3_client = boto3.client('s3')
MAX_FILE_SIZE_BYTES = int(os.environ.get('MAX_FILE_SIZE_BYTES', str(15 * 1024 * 1024))) # 15 MB default

def lambda_handler(event, context):
    """
    Step 1 in Step Functions: Validates the incoming S3 object.
    Checks file existence, extension, and content size.
    """
    bucket = event.get('sourceBucket')
    key = event.get('sourceKey')

    if not bucket or not key:
        raise ValueError("Missing 'sourceBucket' or 'sourceKey' in event payload.")

    # Check extension
    valid_extensions = ('.jpg', '.jpeg', '.png', '.webp')
    if not key.lower().endswith(valid_extensions):
        raise ValueError(f"File '{key}' has an unsupported extension. Allowed: {valid_extensions}")

    try:
        response = s3_client.head_object(Bucket=bucket, Key=key)
        content_length = response.get('ContentLength', 0)
        content_type = response.get('ContentType', 'application/octet-stream')

        if content_length > MAX_FILE_SIZE_BYTES:
            raise ValueError(f"File size {content_length} bytes exceeds maximum allowed limit of {MAX_FILE_SIZE_BYTES} bytes.")

        image_id = key.split('/')[-1].split('.')[0]

        return {
            "isValid": True,
            "sourceBucket": bucket,
            "sourceKey": key,
            "imageId": image_id,
            "contentType": content_type,
            "contentLength": content_length,
            "status": "VALIDATED"
        }

    except Exception as e:
        print(f"Validation failed for s3://{bucket}/{key}: {str(e)}")
        raise e
