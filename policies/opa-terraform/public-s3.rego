package terraform.aws.s3

deny[msg] {
    resource := input.resource.aws_s3_bucket[name]
    not resource.acl
    msg := sprintf("S3 bucket %v must have an explicit ACL or use aws_s3_bucket_public_access_block", [name])
}

deny[msg] {
    resource := input.resource.aws_s3_bucket_public_access_block[name]
    not resource.block_public_acls
    msg := sprintf("S3 bucket public access block %v must block public ACLs", [name])
}
