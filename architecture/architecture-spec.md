# Architecture Specification & Design Decisions

This document details the architecture design decisions, Well-Architected Framework alignment, and technical trade-offs for the **Serverless Image Processing Pipeline**.

---

## 1. Architectural Decisions (ADRs)

### ADR-001: Event Decoupling with Amazon SQS vs. Direct S3 Event to Lambda
* **Context**: S3 can trigger Lambda directly via `s3:ObjectCreated:*` notifications. However, a sudden burst of thousands of image uploads could exceed Lambda concurrency limits, leading to throttles and lost events.
* **Decision**: Place an Amazon SQS FIFO/Standard queue between S3 and the processing workflow.
* **Benefits**:
  * **Buffer Bursts**: Absorbs spikes in traffic without overwhelming downstream functions.
  * **Configurable Batching**: Allows Lambda to process up to 10 messages per invocation.
  * **Failure Isolation**: Messages that repeatedly fail (after 3 attempts) are moved to an SQS Dead-Letter Queue (DLQ) without losing data.

### ADR-002: Orchestration with AWS Step Functions vs. Single Monolithic Lambda
* **Context**: Image processing involves validation, multi-resolution resizing, watermarking, database updates, and notifications.
* **Decision**: Orchestrate individual single-purpose Lambda functions using AWS Step Functions (Standard Workflow).
* **Benefits**:
  * **Single Responsibility Principle**: Each Lambda function does one thing (resizing, watermarking, or indexing) and uses appropriate memory configurations (e.g., 1024MB for Pillow vs. 256MB for metadata).
  * **Built-in Retry & Backoff**: Exponential backoff and jitter handle transient S3/DynamoDB errors automatically.
  * **Visual Debugging**: Step Functions console provides full visual execution history and input/output payloads at every step.

### ADR-003: Direct Uploads via S3 Pre-Signed URLs vs. API Gateway Binary Payload
* **Context**: Uploading multi-megabyte binary images through API Gateway and Lambda incurs high latency, memory costs, and hits the API Gateway 10MB payload limit.
* **Decision**: Use API Gateway and Lambda solely to generate time-limited (300 seconds) S3 Pre-signed URLs for direct browser-to-S3 uploads.
* **Benefits**:
  * Offloads heavy file transfers to Amazon S3 high-speed infrastructure.
  * API Gateway handles only tiny JSON payloads (< 1KB).
  * Low latency and reduced compute costs.

### ADR-004: Amazon CloudFront with Origin Access Control (OAC) vs. Public S3
* **Context**: Processed images must be served globally with minimum latency. Making S3 buckets publicly readable exposes assets to scraping, hotlinking, and unauthorized access.
* **Decision**: Keep the destination S3 bucket strictly private and restrict access exclusively to Amazon CloudFront using modern Origin Access Control (OAC) with SigV4 signing.
* **Benefits**:
  * S3 Block Public Access remains 100% enabled.
  * Global edge caching reduces latency by up to 80% for worldwide viewers.
  * Up to 300+ Point of Presence (PoP) edge nodes reduce egress bandwidth costs.

---

## 2. AWS Well-Architected Framework Alignment

| Pillar | Architectural Implementation |
|---|---|
| **Operational Excellence** | Infrastructure defined as code (Terraform & CloudFormation). CloudWatch logs with 14-day retention. AWS Step Functions visual execution graphs. Detailed SNS alerts for pipeline failures. |
| **Security** | S3 Block Public Access enabled on all buckets. Encryption at rest via SSE-S3. Fine-grained IAM roles with least privilege. CloudFront Origin Access Control (OAC). Pre-signed URLs with 5-minute expiration. |
| **Reliability** | SQS queue buffers sudden traffic spikes. SQS Dead-Letter Queue (DLQ) preserves failed uploads. Step Functions automated exponential backoff and error catch blocks. DynamoDB Point-in-Time Recovery (PITR). |
| **Performance Efficiency** | S3 direct pre-signed uploads bypass API Gateway bandwidth limits. Lambda functions sized specifically for their workloads (1024 MB for CPU-intensive image resizing; 256 MB for metadata). CloudFront edge caching. |
| **Cost Optimization** | 100% Serverless architecture (pay only when images are uploaded; $0 idle cost). S3 Lifecycle rules transition raw uploads to Standard-IA after 30 days and delete after 90 days. Processed images use Intelligent-Tiering. DynamoDB On-Demand capacity. |
| **Sustainability** | Serverless compute scales down to zero when idle, minimizing unnecessary data center electricity and server footprint. |
