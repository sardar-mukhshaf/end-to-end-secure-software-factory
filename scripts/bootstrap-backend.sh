#!/usr/bin/env bash
set -euo pipefail

# bootstrap-backend.sh
# Idempotent S3 + DynamoDB backend bootstrap for Terraform remote state

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Backend configuration is passed via environment variables or defaults below

BUCKET_NAME="${TF_STATE_BUCKET:-ssf-terraform-state-$(aws sts get-caller-identity --query Account --output text)}"
DYNAMODB_TABLE="${TF_LOCK_TABLE:-ssf-terraform-locks}"
REGION="${AWS_REGION:-me-central-1}"
PROJECT="${PROJECT_NAME:-secure-software-factory}"

aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null || {
  echo "[BOOTSTRAP] Creating S3 bucket: ${BUCKET_NAME}"
  aws s3api create-bucket \
    --bucket "${BUCKET_NAME}" \
    --region "${REGION}" \
    --create-bucket-configuration LocationConstraint="${REGION}" 2>/dev/null || \
  aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${REGION}"

  aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "aws:kms",
          "KMSMasterKeyID": "alias/aws/s3"
        },
        "BucketKeyEnabled": true
      }]
    }'

  aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

  aws s3api put-bucket-logging \
    --bucket "${BUCKET_NAME}" \
    --bucket-logging-status '{
      "LoggingEnabled": {
        "TargetBucket": "'${BUCKET_NAME}'",
        "TargetPrefix": "access-logs/"
      }
    }'
}

aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${REGION}" >/dev/null 2>&1 || {
  echo "[BOOTSTRAP] Creating DynamoDB table: ${DYNAMODB_TABLE}"
  aws dynamodb create-table \
    --table-name "${DYNAMODB_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"
}

echo "[BOOTSTRAP] Backend resources ready."
echo "  S3 Bucket: ${BUCKET_NAME}"
echo "  DynamoDB:  ${DYNAMODB_TABLE}"
echo "  Region:    ${REGION}"
