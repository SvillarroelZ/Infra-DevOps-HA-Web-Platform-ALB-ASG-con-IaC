# outputs.tf
# Purpose
# Key outputs to support verification and evidence capture.

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.alb.dns_name
}

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.haweb.id
}

output "autoscaling_group_name" {
  description = "Auto Scaling group name."
  value       = aws_autoscaling_group.asg.name
}

output "dynamodb_table_name" {
  description = "DynamoDB table name."
  value       = aws_dynamodb_table.ddb.name
}
