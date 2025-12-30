# variables.tf
# Purpose
# Define input variables for the Terraform implementation.
# The Terraform configuration mirrors the CloudFormation template to demonstrate IaC parity.

variable "aws_region" {
  description = "AWS region where resources will be created."
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment tag and naming component."
  type        = string
  default     = "dev"
}

variable "resource_prefix" {
  description = "Resource prefix for all infrastructure components (e.g., infra-ha-web-dev). Used for Name tags and deterministic naming."
  type        = string
  default     = "infra-ha-web-dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet1_cidr" {
  description = "CIDR block for public subnet in AZ1."
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet2_cidr" {
  description = "CIDR block for public subnet in AZ2."
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet1_cidr" {
  description = "CIDR block for private subnet in AZ1."
  type        = string
  default     = "10.0.11.0/24"
}

variable "private_subnet2_cidr" {
  description = "CIDR block for private subnet in AZ2."
  type        = string
  default     = "10.0.12.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for ASG instances."
  type        = string
  default     = "t2.micro"
}

variable "desired_capacity" {
  description = "Desired instance count for the Auto Scaling group."
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum instance count for the Auto Scaling group."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum instance count for the Auto Scaling group."
  type        = number
  default     = 2
}

variable "create_ddb_vpc_endpoint" {
  description = "Whether to create the DynamoDB VPC endpoint. Some lab roles may block this action."
  type        = bool
  default     = true
}
