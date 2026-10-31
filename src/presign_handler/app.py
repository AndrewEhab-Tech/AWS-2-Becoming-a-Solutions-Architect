import json
import os
import uuid
import boto3
from botocore.exceptions import ClientError

s3_client = boto3.client('s3')
SOURCE_BUCKET = os.environ.get('SOURCE_BUCKET_NAME')
URL_EXPIRATION = int(os.environ.get('URL_EXPIRATION_SECONDS', '300'))

def lambda_handler(event, context):
    """
    Generates a secure S3 Pre-signed URL for direct browser uploads.
    Handles CORS headers and payload validation.
    """
    cors_headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "POST,OPTIONS"
    }

    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': ''
        }

    try:
        body = json.loads(event.get('body', '{}')) if event.get('body') else {}
        file_name = body.get('fileName', 'image.jpg')
        content_type = body.get('contentType', 'image/jpeg')

        # Allowed image mime-types
        allowed_types = ['image/jpeg', 'image/png', 'image/webp']
        if content_type not in allowed_types:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': f'Unsupported content type: {content_type}. Allowed: {allowed_types}'})
            }

        # Generate unique key
        file_extension = file_name.split('.')[-1].lower() if '.' in file_name else 'jpg'
        unique_id = str(uuid.uuid4())
        s3_key = f"uploads/{unique_id}.{file_extension}"

        # Generate presigned PUT URL
        presigned_url = s3_client.generate_presigned_url(
            ClientMethod='put_object',
            Params={
                'Bucket': SOURCE_BUCKET,
                'Key': s3_key,
                'ContentType': content_type
            },
            ExpiresIn=URL_EXPIRATION
        )

        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({
                'uploadUrl': presigned_url,
                'key': s3_key,
                'imageId': unique_id,
                'bucket': SOURCE_BUCKET,
                'expiresInSeconds': URL_EXPIRATION
            })
        }

    except Exception as e:
        print(f"Error generating presigned URL: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': 'Failed to generate pre-signed upload URL', 'details': str(e)})
        }
