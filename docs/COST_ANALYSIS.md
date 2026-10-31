# Cost Optimization & AWS Free Tier Analysis

This document details the cost profile for the **Serverless Image Processing Pipeline**, highlighting how it complies with the AWS Well-Architected Framework's **Cost Optimization** pillar.

---

## 💡 Key Architectural Cost Benefits

1. **Zero Idle Cost**: No servers, no containers, and no databases are running when idle. Total idle cost = **$0.00 / month**.
2. **100% AWS Free Tier Friendly**: All services utilized have generous ongoing Free Tier allowances or 12-month free tier coverage.
3. **Optimized Storage Tiering**: S3 lifecycle rules automatically transition older objects to infrequent access and delete temporary raw uploads after 90 days.

---

## 📊 Monthly Cost Breakdown (Under Free Tier)

| AWS Service | Free Tier Allowance | Project Usage (Demo Scale) | Estimated Monthly Cost |
|---|---|---|---|
| **AWS Lambda** | 1,000,000 requests/mo + 3.2M sec compute | ~5,000 requests / ~2,500 sec | **$0.00** |
| **Amazon S3** | 5 GB Standard Storage + 20,000 GETs | ~100 MB storage | **$0.00** |
| **Amazon SQS** | 1,000,000 requests/mo | ~5,000 requests | **$0.00** |
| **AWS Step Functions** | 4,000 state transitions/mo | ~1,000 transitions | **$0.00** |
| **Amazon DynamoDB** | 25 GB storage + 25 RCU/WCU (or On-Demand free) | < 1 MB data | **$0.00** |
| **Amazon CloudFront** | 1 TB data transfer out + 10M requests | < 1 GB data transfer | **$0.00** |
| **Amazon SNS** | 1,000,000 publishes/mo + 1,000 email deliveries | < 100 emails | **$0.00** |
| **Amazon API Gateway** | 1,000,000 REST API calls/mo (12 mo Free Tier) | < 1,000 calls | **$0.00** |
| **Total Cost** | | | **$0.00 / month** |

---

## 📈 Scaled Production Cost Estimation (100,000 Images / Month)

If this pipeline processes **100,000 images per month** (average 2 MB raw image size, generating 3 variants + 1 watermark):

- **S3 Storage & Ingestion**:
  - Ingestion (100K PUTs) = ~$0.50
  - Storage (50 GB active storage) = ~$1.15
  - Lifecycle savings (IA after 30d, expiration after 90d) saves ~60% of long-term storage costs.
- **AWS Lambda**:
  - 100K executions * 5 steps = 500K invocations.
  - Sits within or slightly above Free Tier: ~$0.85
- **AWS Step Functions**:
  - 500K state transitions: (500,000 - 4,000 free) * $0.000025 = ~$12.40
- **Amazon SQS**:
  - 100K messages = negligible (~$0.04)
- **Amazon DynamoDB**:
  - 100K write requests + queries = ~$0.15
- **Amazon CloudFront**:
  - 100K edge downloads (~50 GB transfer) = ~$4.25

**Total estimated cost for 100,000 processed images:** **~$19.34 / month** (~$0.00019 per processed image).
