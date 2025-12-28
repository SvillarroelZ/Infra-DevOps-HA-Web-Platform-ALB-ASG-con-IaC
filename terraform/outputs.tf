output "dynamodb_table_id" {
  description = "ID of the DynamoDB table for persistence."
  value       = aws_dynamodb_table.web_platform_table.id
}
# outputs.tf - Key outputs for the HA Web Platform Terraform configuration
#
# Abstract: This file exports all key outputs for integration, documentation, and evidence. All comments are in English, concise, and line-based, explaining what and why each output exists.


output "vpc_id" {
  description = "VPC ID created for the web platform."
  value       = aws_vpc.web_platform_vpc.id
}

output "public_subnet1_id" {
  description = "ID of public subnet 1 (AZ1)."
  value       = aws_subnet.public_subnet_az1.id
}

output "public_subnet2_id" {
  description = "ID of public subnet 2 (AZ2)."
  value       = aws_subnet.public_subnet_az2.id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (ALB)."
  value       = aws_lb.web_platform_alb.dns_name
}

output "asg_name" {
  description = "Name of the Auto Scaling Group (ASG)."
  value       = aws_autoscaling_group.web_platform_asg.name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for persistence."
  value       = aws_dynamodb_table.web_platform_table.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for persistence."
  value       = aws_dynamodb_table.web_platform_table.arn
}
