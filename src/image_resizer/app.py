import io
import os
import boto3
from PIL import Image

s3_client = boto3.client('s3')
DESTINATION_BUCKET = os.environ.get('DESTINATION_BUCKET_NAME')

RESIZE_CONFIGS = {
    'thumbnail': (200, 200),
    'medium': (800, 800),
    'large': (1600, 1600)
}

def lambda_handler(event, context):
    """
    Step 2 in Step Functions: Resizes the validated image into multiple
    resolutions (thumbnail, medium, large) and saves them to the destination bucket.
    """
    source_bucket = event['sourceBucket']
    source_key = event['sourceKey']
    image_id = event['imageId']
    destination_bucket = DESTINATION_BUCKET or os.environ.get('DESTINATION_BUCKET')

    print(f"Downloading original image s3://{source_bucket}/{source_key}...")
    s3_obj = s3_client.get_object(Bucket=source_bucket, Key=source_key)
    image_bytes = s3_obj['Body'].read()

    original_img = Image.open(io.BytesIO(image_bytes))
    orig_format = original_img.format or 'JPEG'
    orig_width, orig_height = original_img.size

    # Convert RGBA to RGB for JPEG compatibility
    if orig_format.upper() in ['JPEG', 'JPG'] and original_img.mode in ('RGBA', 'P', 'LA'):
        original_img = original_img.convert('RGB')

    output_files = {}

    for size_name, max_dims in RESIZE_CONFIGS.items():
        img_copy = original_img.copy()
        img_copy.thumbnail(max_dims, Image.Resampling.LANCZOS)

        buffer = io.BytesIO()
        save_format = 'PNG' if orig_format.upper() == 'PNG' else 'JPEG'
        content_type = f"image/{save_format.lower()}"

        img_copy.save(buffer, format=save_format, quality=85, optimize=True)
        buffer.seek(0)

        dest_key = f"processed/{image_id}/{size_name}.{save_format.lower()}"

        s3_client.put_object(
            Bucket=destination_bucket,
            Key=dest_key,
            Body=buffer,
            ContentType=content_type,
            Metadata={
                'source-key': source_key,
                'variant': size_name,
                'width': str(img_copy.width),
                'height': str(img_copy.height)
            }
        )

        output_files[size_name] = {
            'key': dest_key,
            'width': img_copy.width,
            'height': img_copy.height,
            'sizeBytes': buffer.getbuffer().nbytes
        }

    return {
        **event,
        "destinationBucket": destination_bucket,
        "originalDimensions": {"width": orig_width, "height": orig_height},
        "variants": output_files,
        "status": "RESIZED"
    }
