provider "aws" {
    version     = "~> 0.1"
    region      = "${var.aws_region}"
}

variable "aws_region" {
    type    = "string"
    description = "AWS region only (no zone)"
}

variable "aws_zone_suffix" {
    type = "string"
    description = "AWS zone suffix"
    default = "a"
}

resource "random_string" "suffix" {
    length  = 8
    special = false
    upper   = false
}

output "PACKER_AWS_VPC_ID" {
    value = "${aws_vpc.packer-builder.id}"
}

resource "aws_vpc" "packer-builder" {
    cidr_block           = "10.20.254.0/24"
    enable_dns_hostnames = true
    enable_dns_support   = true
    instance_tenancy     = "default"

    tags {
        Name = "packer-${random_string.suffix.result}"
    }
}

resource "aws_subnet" "packer-builder" {
    count                   = "1"
    vpc_id                  = "${aws_vpc.packer-builder.id}"
    cidr_block              = "10.20.254.0/24"
    availability_zone       = "${var.aws_region}${var.aws_zone_suffix}"
    map_public_ip_on_launch = true

    tags {
        Name = "${var.prefix}public-${count.index}"
        Name = "packer-${random_string.suffix.result}"
    }
}

resource "aws_security_group" "packer-builder" {
    name        = "packer-${random_string.suffix.result}"
    vpc_id      = "${aws_vpc.packer-builder.id}"

    tags {
        Name = "packer-${random_string.suffix.result}"
    }
}

resource "aws_security_group_rule" "packer-builder-22" {
    type            = "ingress"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.packer-builder.id}"
}

resource "aws_security_group_rule" "packer-builder-all" {
    type            = "egress"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.packer-builder.id}"
}
