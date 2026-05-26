package terraform.aws.ebs

deny[msg] {
    resource := input.resource.aws_ebs_volume[name]
    not resource.encrypted
    msg := sprintf("EBS volume %v must be encrypted", [name])
}

deny[msg] {
    resource := input.resource.aws_ebs_volume[name]
    resource.encrypted == false
    msg := sprintf("EBS volume %v must have encrypted = true", [name])
}
