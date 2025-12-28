
# variables.tf - Input variables for the HA Web Platform Terraform configuration
#
# Abstract: This file defines all input variables for modular, secure, and cost-controlled deployment. All comments are in English, concise, and line-based, explaining what and why each variable exists.
variable "environment" {
  description = "Deployment environment (dev, test, prod). Used for resource naming and tags."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy all resources."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet1_cidr" {
  description = "CIDR block for public subnet 1 (AZ1)."
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet2_cidr" {
  description = "CIDR block for public subnet 2 (AZ2)."
  type        = string
  default     = "10.0.2.0/24"
}

variable "az1" {
  description = "Availability Zone for public subnet 1."
  type        = string
  default     = "us-east-1a"
}

variable "az2" {
  description = "Availability Zone for public subnet 2."
  type        = string
  default     = "us-east-1b"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances. Leave blank to use the latest Amazon Linux 2 AMI automatically."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t2.micro"
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances in the Auto Scaling Group."
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of EC2 instances in ASG."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of EC2 instances in ASG."
  type        = number
  default     = 2
}
