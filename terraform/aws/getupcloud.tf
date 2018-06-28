locals {
    getupcloud_api_aws_bucket_name = "${var.prefix}api-${random_string.suffix.result}"
    getupcloud_namespace_backup_aws_bucket_name = "${var.prefix}namespace-backup-${random_string.suffix.result}"
    iam_user_getupcloud_api = "${var.prefix}api-${random_string.suffix.result}"
    iam_user_getupcloud_backup = "${var.prefix}namespace-backup-${random_string.suffix.result}"
}

#################################################################
## Getup API
#################################################################

resource "aws_iam_user" "getupcloud-api" {
    name = "${local.iam_user_getupcloud_api}"
    path = "/"
}

resource "aws_iam_user_policy" "getupcloud-api" {
    name   = "${var.prefix}api-${random_string.suffix.result}"
    user   = "${aws_iam_user.getupcloud-api.name}"
    policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Resource": "arn:aws:s3:::${local.getupcloud_api_aws_bucket_name}/*",
      "Effect": "Allow"
    }
  ]
}
POLICY
}

resource "aws_iam_access_key" "getupcloud-api" {
  user    = "${aws_iam_user.getupcloud-api.name}"
}

resource "aws_s3_bucket" "getupcloud-api" {
    bucket = "${local.getupcloud_api_aws_bucket_name}"
    acl    = "public-read"
    force_destroy = true

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${local.getupcloud_api_aws_bucket_name}"
    }
}

#################################################################
## Getup Backup
#################################################################

resource "aws_iam_user" "getupcloud-namespace-backup" {
    name = "${local.iam_user_getupcloud_api}"
    path = "/"
}

resource "aws_iam_user_policy" "getupcloud-namespace-backup" {
    name   = "${var.prefix}namespace-backup-${random_string.suffix.result}"
    user   = "${aws_iam_user.getupcloud-namespace-backup.name}"
    policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "ec2:DeleteSnapshot",
                "ec2:ModifySnapshotAttribute",
                "ec2:CreateTags",
                "ec2:CreateSnapshot",
                "iam:GetUser"
            ],
            "Resource": [
                "arn:aws:ec2:*:${data.aws_user.user_id}:volume/*",
                "arn:aws:ec2:*::snapshot/*",
                "arn:aws:s3:::${local.getupcloud_namespace_backup_aws_bucket_name}/*",
                "arn:aws:iam::${data.aws_user.user_id}:user/${aws_iam_user.getupcloud-namespace-backup.name}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVolumes",
                "iam:GetUser",
                "ec2:DescribeSnapshots"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_iam_access_key" "getupcloud-namespace-backup" {
  user    = "${aws_iam_user.getupcloud-namespace-backup.name}"
}

resource "aws_s3_bucket" "getupcloud-namespace-backup" {
    bucket = "${local.getupcloud_namespace_backup_aws_bucket_name}"
    acl    = "private"

    tags {
        ResourceGroup = "${var.aws_resource_group}"
        Name = "${local.getupcloud_namespace_backup_aws_bucket_name}"
    }
}

#################################################################
## Outputs
#################################################################

# API
########

output "GETUPCLOUD_API_AWS_STORAGE_BUCKET_NAME" {
    value = "${aws_s3_bucket.getupcloud-api.id}"
}

output "GETUPCLOUD_API_AWS_REGION" {
    value = "${aws_s3_bucket.getupcloud-api.region}"
}

output "GETUPCLOUD_API_AWS_ACCESS_KEY_ID" {
    value = "${aws_iam_access_key.getupcloud-api.id}"
}

output "GETUPCLOUD_API_AWS_SECRET_ACCESS_KEY" {
    value = "${aws_iam_access_key.getupcloud-api.secret}"
}

output "GETUPCLOUD_API_STORAGE_BACKEND" {
    value = "storages.backends.s3boto3.S3Boto3Storage"
}

# Database
##########

output "GETUPCLOUD_DATABASE_MODE" {
    value = "hosted"
}

# Backup
########

output "GETUPCLOUD_BACKUP_STORAGE_S3_BUCKET" {
    value = "${aws_s3_bucket.getupcloud-namespace-backup.id}"
}

output "GETUPCLOUD_BACKUP_STORAGE_S3_REGION" {
    value = "${aws_s3_bucket.getupcloud-namespace-backup.region}"
}

output "GETUPCLOUD_BACKUP_STORAGE_S3_ACCESSKEY" {
    value = "${aws_iam_access_key.getupcloud-namespace-backup.id}"
}

output "GETUPCLOUD_BACKUP_STORAGE_S3_SECRETKEY" {
    value = "${aws_iam_access_key.getupcloud-namespace-backup.secret}"
}

output "GETUPCLOUD_BACKUP_STORAGE_KIND" {
    value = "s3"
}
