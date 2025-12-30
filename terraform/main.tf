# main.tf
# Purpose
# Terraform implementation of the same architecture as iac/main.yaml.
# This exists to demonstrate a second IaC approach for portfolio and interviews.
#
# Notes
# The CloudFormation path is the primary deployment method for this repository.
# Terraform is provided as an equivalently deep example.
# Some lab environments restrict actions like VPC endpoint creation.
# Use var.create_ddb_vpc_endpoint=false if you encounter permission errors.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Project     = "ha-web-platform"
    Environment = var.environment
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_vpc" "haweb" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.haweb.id

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-igw"
  })
}

resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.haweb.id
  cidr_block              = var.public_subnet1_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-subnet-public-az1"
  })
}

resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.haweb.id
  cidr_block              = var.public_subnet2_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-subnet-public-az2"
  })
}

resource "aws_subnet" "private_az1" {
  vpc_id                  = aws_vpc.haweb.id
  cidr_block              = var.private_subnet1_cidr
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-subnet-private-az1"
  })
}

resource "aws_subnet" "private_az2" {
  vpc_id                  = aws_vpc.haweb.id
  cidr_block              = var.private_subnet2_cidr
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-subnet-private-az2"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.haweb.id

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-rt-public"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_az1" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-eip-nat"
  })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_az1.id

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-nat"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.haweb.id

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-rt-private"
  })
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private_az1" {
  subnet_id      = aws_subnet.private_az1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_az2" {
  subnet_id      = aws_subnet.private_az2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb" {
  name        = "${var.resource_prefix}-sg-alb"
  description = "Allow inbound HTTP from the Internet to the ALB."
  vpc_id      = aws_vpc.haweb.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-sg-alb"
  })
}

resource "aws_security_group" "ec2" {
  name        = "${var.resource_prefix}-sg-ec2"
  description = "Allow inbound HTTP only from the ALB security group."
  vpc_id      = aws_vpc.haweb.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-sg-ec2"
  })
}

resource "aws_lb" "alb" {
  name               = substr(replace("${var.resource_prefix}-alb", "_", "-"), 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-alb"
  })
}

resource "aws_lb_target_group" "tg" {
  name     = substr(replace("${var.resource_prefix}-tg", "_", "-"), 0, 32)
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.haweb.id

  health_check {
    path                = "/health.html"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 15
    matcher             = "200"
  }

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-tg"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_launch_template" "lt" {
  name_prefix   = "${var.resource_prefix}-lt-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    environment     = var.environment
    resource_prefix = var.resource_prefix
    aws_region      = var.aws_region
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${var.resource_prefix}-i"
    })
  }

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-lt"
  })
}

resource "aws_autoscaling_group" "asg" {
  name                      = "${var.resource_prefix}-asg"
  vpc_zone_identifier       = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
  desired_capacity          = var.desired_capacity
  min_size                  = var.min_size
  max_size                  = var.max_size
  health_check_type         = "ELB"
  health_check_grace_period = 90
  target_group_arns         = [aws_lb_target_group.tg.arn]

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.resource_prefix}-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "ha-web-platform"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

resource "aws_dynamodb_table" "ddb" {
  name         = "${var.resource_prefix}-ddb"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-ddb"
  })
}

resource "aws_vpc_endpoint" "ddb" {
  count             = var.create_ddb_vpc_endpoint ? 1 : 0
  vpc_id            = aws_vpc.haweb.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(local.common_tags, {
    Name = "${var.resource_prefix}-vpce-ddb"
  })
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.resource_prefix}-cpu-high"
  alarm_description   = "Example alarm when average CPU is high across the Auto Scaling group."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}
