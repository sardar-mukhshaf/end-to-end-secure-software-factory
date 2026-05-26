bucket         = "ssf-terraform-state-123456789012"
key            = "staging/terraform.tfstate"
region         = "me-central-1"
encrypt        = true
kms_key_id     = "alias/aws/s3"
dynamodb_table = "ssf-terraform-locks"
