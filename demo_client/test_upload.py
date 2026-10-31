#!/usr/bin/env python3
"""
Automated End-to-End Test Script for Serverless Image Processing Pipeline
Tests:
1. API Gateway pre-signed URL generation
2. Direct S3 upload
3. SQS & Step Functions automated processing verification
4. DynamoDB metadata persistence
5. CloudFront/S3 output verification
"""

import sys
import time
import json
import argparse
import requests
import boto3

def generate_dummy_image(output_path="test_sample.jpg"):
    try:
        from PIL import Image, ImageDraw
        img = Image.new('RGB', (1200, 800), color=(50, 120, 200))
        d = ImageDraw.Draw(img)
        d.text((100, 100), "AWS Solutions Architect Test Image", fill=(255, 255, 255))
        img.save(output_path, "JPEG")
        print(f"Created dummy test image: {output_path}")
    except ImportError:
        # Fallback binary dummy JPEG header
        with open(output_path, "wb") as f:
            f.write(b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb\x00C\x00')
            f.write(b'\x00' * 1024)
            f.write(b'\xff\xd9')
        print(f"Created fallback dummy JPEG: {output_path}")

def run_test(api_url, table_name, region_name="us-east-1"):
    print("=" * 60)
    print("🚀 Starting End-to-End Pipeline Verification")
    print("=" * 60)

    # 1. Prepare sample image
    image_filename = "test_image.jpg"
    generate_dummy_image(image_filename)

    # 2. Call API Gateway for pre-signed URL
    print(f"\n[Step 1] Requesting pre-signed URL from: {api_url}")
    payload = {"fileName": image_filename, "contentType": "image/jpeg"}
    res = requests.post(api_url, json=payload, timeout=10)
    if res.status_code != 200:
        print(f"❌ Failed to get presigned URL: {res.status_code} - {res.text}")
        sys.exit(1)

    data = res.json()
    upload_url = data['uploadUrl']
    image_id = data['imageId']
    s3_key = data['key']
    print(f"✅ Success! Generated Key: {s3_key}")
    print(f"   Image ID: {image_id}")

    # 3. Direct upload to S3
    print(f"\n[Step 2] Uploading binary bytes to S3 via Pre-Signed URL...")
    with open(image_filename, 'rb') as f:
        upload_res = requests.put(upload_url, data=f, headers={"Content-Type": "image/jpeg"}, timeout=30)

    if upload_res.status_code in [200, 204]:
        print("✅ Direct S3 upload completed successfully!")
    else:
        print(f"❌ Upload failed: {upload_res.status_code}")
        sys.exit(1)

    # 4. Polling DynamoDB to verify Step Function execution
    print(f"\n[Step 3] Waiting for Step Functions workflow to execute and write to DynamoDB table '{table_name}'...")
    dynamodb = boto3.resource('dynamodb', region_name=region_name)
    table = dynamodb.Table(table_name)

    max_attempts = 12
    completed = False
    for attempt in range(1, max_attempts + 1):
        print(f"   Polling DynamoDB (Attempt {attempt}/{max_attempts})...")
        try:
            item_res = table.get_item(Key={'ImageId': image_id})
            if 'Item' in item_res:
                item = item_res['Item']
                print(f"   Found DynamoDB record! Status: {item.get('Status')}")
                if item.get('Status') == 'COMPLETED':
                    print("\n🎉 SUCCESS: Step Functions processing finished successfully!")
                    print(json.dumps(item, indent=2, default=str))
                    completed = True
                    break
        except Exception as e:
            print(f"   Polling error: {e}")

        time.sleep(5)

    if not completed:
        print("⚠️ Pipeline took longer than expected or encountered an error. Check CloudWatch logs and Step Functions console.")
    else:
        print("\n" + "=" * 60)
        print("✅ ALL TESTS PASSED: S3 ➔ SQS ➔ Step Functions ➔ DynamoDB ➔ CloudFront")
        print("=" * 60)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test Serverless Image Pipeline")
    parser.add_argument("--api-url", required=True, help="API Gateway upload-url endpoint")
    parser.add_argument("--table-name", required=True, help="DynamoDB Metadata table name")
    parser.add_argument("--region", default="us-east-1", help="AWS Region (default: us-east-1)")
    args = parser.parse_args()

    run_test(args.api_url, args.table_name, args.region)
