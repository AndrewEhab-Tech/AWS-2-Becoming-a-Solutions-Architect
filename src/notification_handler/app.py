import json
import os
import boto3

sns_client = boto3.client('sns')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')

def lambda_handler(event, context):
    """
    Step 5 in Step Functions (or Failure Catch Handler):
    Sends an Amazon SNS notification upon workflow completion or error.
    """
    status = event.get('status', 'SUCCESS')
    image_id = event.get('imageId', 'Unknown')

    if 'Error' in event:
        # Handling failure notification
        subject = f"❌ [ALERT] Image Processing Failed: {image_id}"
        message = {
            "status": "FAILED",
            "error": event.get('Error'),
            "cause": event.get('Cause'),
            "input": event.get('ExecutionInput', {})
        }
    else:
        # Handling success notification
        subject = f"✅ [SUCCESS] Image Processed Successfully: {image_id}"
        variants = event.get('variants', {})
        message = {
            "status": "SUCCESS",
            "imageId": image_id,
            "originalKey": event.get('sourceKey'),
            "generatedVariants": list(variants.keys()),
            "details": event.get('metadataRecord', {})
        }

    print(f"Publishing SNS notification: {subject}")
    response = sns_client.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=subject[:100],
        Message=json.dumps(message, indent=2, default=str)
    )

    return {
        "messageId": response.get('MessageId'),
        "published": True,
        "status": status
    }
