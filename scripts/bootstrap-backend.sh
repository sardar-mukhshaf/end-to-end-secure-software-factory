#!/usr/bin/env bash
set -euo pipefail

# bootstrap-backend.sh
# Idempotent S3 + DynamoDB backend bootstrap for Terraform remote state

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse variables from centralized terraform.tfvars in the root if it exists
TFVARS_FILE="${SCRIPT_DIR}/../terraform.tfvars"
TFVARS_REGION=""
TFVARS_PROJECT=""

if [ -f "${TFVARS_FILE}" ]; then
  TFVARS_REGION=$(grep -E '^\s*aws_region\s*=' "${TFVARS_FILE}" | cut -d'"' -f2)
  TFVARS_PROJECT=$(grep -E '^\s*project_name\s*=' "${TFVARS_FILE}" | cut -d'"' -f2)
fi

REGION="${AWS_REGION:-${TFVARS_REGION:-me-central-1}}"
PROJECT="${PROJECT_NAME:-${TFVARS_PROJECT:-ssf}}"
BUCKET_NAME="${TF_STATE_BUCKET:-${PROJECT}-terraform-state-\$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "123456789012")}"
DYNAMODB_TABLE="${TF_LOCK_TABLE:-${PROJECT}-terraform-locks}"

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

# Generate backend.hcl for all environments automatically
for ENV_NAME in dev staging prod; do
  ENV_DIR="${SCRIPT_DIR}/../terraform/environments/${ENV_NAME}"
  mkdir -p "${ENV_DIR}"
  cat <<EOF > "${ENV_DIR}/backend.hcl"
bucket         = "${BUCKET_NAME}"
key            = "${ENV_NAME}/terraform.tfstate"
region         = "${REGION}"
encrypt        = true
kms_key_id     = "alias/aws/s3"
dynamodb_table = "${DYNAMODB_TABLE}"
EOF
  echo "[BOOTSTRAP] Generated ${ENV_NAME}/backend.hcl"
done

echo "[BOOTSTRAP] Backend resources ready."
echo "  S3 Bucket: ${BUCKET_NAME}"
echo "  DynamoDB:  ${DYNAMODB_TABLE}"
echo "  Region:    ${REGION}"
