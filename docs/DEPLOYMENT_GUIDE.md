# Deployment & Operations Guide

This guide walks you through deploying the **Serverless Image Processing Pipeline** to your AWS account using either **Terraform** (recommended) or **AWS CloudFormation**.

---

## 📋 Prerequisites

1. **AWS Account**: An active AWS account with administrative permissions.
2. **AWS CLI**: Installed and configured (`aws configure`).
3. **Terraform**: Version >= 1.3.0 installed (if using Terraform).
4. **Python**: Version >= 3.10 with `pip`.

Verify your CLI configuration:
```bash
aws sts get-caller-identity
```

---

## 🚀 Option A: Deploying with Terraform (Recommended)

### Step 1: Navigate to the Terraform Directory
```bash
cd terraform
```

### Step 2: Configure Variables
Copy the example variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```
Edit `terraform.tfvars` and set your desired values:
```hcl
aws_region         = "us-east-1"
project_name       = "serverless-image-pipeline"
notification_email = "your-actual-email@example.com"
```

### Step 3: Initialize Terraform
```bash
terraform init
```

### Step 4: Preview Infrastructure Changes
```bash
terraform plan
```

### Step 5: Provision Resources
```bash
terraform apply -auto-approve
```
*Deployment takes approximately 2-4 minutes (primarily CloudFront distribution creation).*

### Step 6: Note Outputs
Upon successful deployment, Terraform outputs important parameters:
* `api_gateway_upload_endpoint`
* `dynamodb_table_name`
* `cloudfront_domain_name`
* `source_bucket_name`
* `destination_bucket_name`

### Step 7: Confirm SNS Email Subscription
Check your inbox for an email from **AWS Notifications** with the subject:
> *"AWS Notification - Subscription Confirmation"*
Click the **Confirm subscription** link.

---

## ☁️ Option B: Deploying with AWS CloudFormation

### Using AWS CLI:
```bash
cd cloudformation

aws cloudformation create-stack \
  --stack-name serverless-image-pipeline \
  --template-body file://template.yaml \
  --parameters ParameterKey=NotificationEmail,ParameterValue=your-email@example.com \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

To monitor stack creation:
```bash
aws cloudformation wait stack-create-complete --stack-name serverless-image-pipeline --region us-east-1
```

---

## 🧪 Testing the Deployment

### Method 1: Using the Web Demo UI
1. Open `demo_client/index.html` in your web browser.
2. Paste the `api_gateway_upload_endpoint` into the endpoint input.
3. (Optional) Paste the `cloudfront_domain_name`.
4. Choose an image (`.jpg` or `.png`) and click **Upload & Trigger Pipeline**.
5. Watch the real-time execution logs!

### Method 2: Using the CLI Test Script
Run the automated end-to-end Python test:
```bash
cd demo_client
python -m pip install requests boto3 pillow
python test_upload.py \
  --api-url "https://<api-id>.execute-api.us-east-1.amazonaws.com/prod/upload-url" \
  --table-name "serverless-image-pipeline-metadata" \
  --region us-east-1
```

---

## 🧹 Resource Teardown (Avoid AWS Charges)

When you have completed your demonstration or project review, destroy all provisioned resources:

### Terraform Destroy:
```bash
cd terraform
terraform destroy -auto-approve
```

### CloudFormation Delete:
```bash
aws cloudformation delete-stack --stack-name serverless-image-pipeline --region us-east-1
```

> **Note**: Both S3 buckets have `force_destroy = true` enabled in Terraform so they are cleaned up automatically even if they contain processed objects.
