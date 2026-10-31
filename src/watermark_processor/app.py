import io
import os
import boto3
from PIL import Image, ImageDraw, ImageFont

s3_client = boto3.client('s3')
WATERMARK_TEXT = os.environ.get('WATERMARK_TEXT', '© AWS SAA Graduation Project')

def lambda_handler(event, context):
    """
    Step 3 in Step Functions: Adds a subtle watermark overlay to the
    medium variant image and saves it to the destination S3 bucket.
    """
    destination_bucket = event['destinationBucket']
    image_id = event['imageId']
    medium_variant = event.get('variants', {}).get('medium')

    if not medium_variant:
        raise ValueError("Missing 'medium' image variant for watermarking.")

    medium_key = medium_variant['key']

    print(f"Downloading {medium_key} for watermarking...")
    s3_obj = s3_client.get_object(Bucket=destination_bucket, Key=medium_key)
    img_data = s3_obj['Body'].read()

    base_image = Image.open(io.BytesIO(img_data)).convert('RGBA')

    # Create transparent overlay for watermark
    overlay = Image.new('RGBA', base_image.size, (255, 255, 255, 0))
    draw = ImageDraw.Draw(overlay)

    font_size = max(18, int(base_image.width * 0.035))
    try:
        font = ImageFont.load_default()
    except Exception:
        font = None

    text = WATERMARK_TEXT
    margin = 20

    # Draw semi-transparent watermark text at bottom-right
    # (r, g, b, alpha) -> alpha 128 is 50% opacity
    draw.text((margin, base_image.height - margin - font_size - 10), text, fill=(255, 255, 255, 160), font=font)

    watermarked = Image.alpha_composite(base_image, overlay).convert('RGB')

    output_buffer = io.BytesIO()
    watermarked.save(output_buffer, format='JPEG', quality=88)
    output_buffer.seek(0)

    watermark_key = f"processed/{image_id}/watermarked.jpg"

    s3_client.put_object(
        Bucket=destination_bucket,
        Key=watermark_key,
        Body=output_buffer,
        ContentType='image/jpeg',
        Metadata={
            'watermarked': 'true',
            'watermark-text': WATERMARK_TEXT
        }
    )

    event['variants']['watermarked'] = {
        'key': watermark_key,
        'width': watermarked.width,
        'height': watermarked.height,
        'sizeBytes': output_buffer.getbuffer().nbytes
    }
    event['status'] = 'WATERMARKED'

    return event
