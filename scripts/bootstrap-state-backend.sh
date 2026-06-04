#!/usr/bin/env bash
#
# Idempotent setup of the Terraform S3 state backend. Run ONCE per AWS account
# before the first `terraform init`. Re-running is safe; every step checks
# first.
#
# Why a script and not Terraform: the state backend cannot be managed by the
# stack that stores its state in it (chicken and egg). A small idempotent
# script is the pragmatic answer. It is version controlled and the AWS calls
# are right here in the open.
#
# Creates:
#   - S3 bucket   (versioned, AES256 encryption, all public access blocked)
#   - DynamoDB    (PAY_PER_REQUEST, LockID hash key) for state locking
#
# Usage:
#   aws sso login --profile <admin>          # or set AWS keys
#   export AWS_PROFILE=<admin>
#   ./scripts/bootstrap-state-backend.sh
#
# Override defaults with env vars or the Makefile:
#   BUCKET=my-tf-state TABLE=my-locks AWS_REGION=us-east-1 ./scripts/bootstrap-state-backend.sh

set -euo pipefail

BUCKET="${BUCKET:-demo-platform-tf-state}"
TABLE="${TABLE:-demo-platform-terraform-locks}"
REGION="${AWS_REGION:-us-east-1}"

echo "==> Account: $(aws sts get-caller-identity --query Account --output text)"
echo "==> Region:  ${REGION}"
echo "==> Bucket:  ${BUCKET}"
echo "==> Table:   ${TABLE}"
echo

if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "[skip] S3 bucket ${BUCKET} already exists"
else
  echo "[create] S3 bucket ${BUCKET}"
  if [ "${REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" >/dev/null
  else
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
  fi
fi

echo "[apply] versioning enabled on ${BUCKET}"
aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

echo "[apply] default encryption AES256 on ${BUCKET}"
aws s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"},
      "BucketKeyEnabled": true
    }]
  }'

echo "[apply] block all public access on ${BUCKET}"
aws s3api put-public-access-block \
  --bucket "${BUCKET}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

if aws dynamodb describe-table --table-name "${TABLE}" --region "${REGION}" >/dev/null 2>&1; then
  echo "[skip] DynamoDB table ${TABLE} already exists"
else
  echo "[create] DynamoDB table ${TABLE}"
  aws dynamodb create-table \
    --table-name "${TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}" >/dev/null
  echo "[wait] table ACTIVE..."
  aws dynamodb wait table-exists --table-name "${TABLE}" --region "${REGION}"
fi

echo
echo "Done. State backend is ready."
echo "Put '${BUCKET}' and '${TABLE}' into your backends/*.hcl files, then run terraform init."
