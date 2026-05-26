terraform {
  backend "s3" {
    bucket         = "ssf-terraform-state"
    key            = "terraform.tfstate"
    region         = "me-central-1"
    encrypt        = true
    kms_key_id     = "alias/aws/s3"
    dynamodb_table = "ssf-terraform-locks"
    profile        = ""
  }
}
