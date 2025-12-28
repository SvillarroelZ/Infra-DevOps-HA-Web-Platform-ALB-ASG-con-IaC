


###################################################################################################
# main.tf - Terraform configuration for the HA Web Platform
#
# Abstract: This file provisions a highly available, secure, and auditable web platform on AWS. It is modular, cost-controlled, and designed for professional portfolio and certification demonstration. All comments are in English, concise, and line-based, explaining what and why each block exists.
###################################################################################################


# ------------------- Provider -------------------
provider "aws" {
  region = var.aws_region
}

data "aws_ami" "latest_amazon_linux" {

# ------------------- Data Sources -------------------
# Lookup the latest Amazon Linux 2 AMI automatically for EC2 instances
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# ------------------- Network Layer -------------------
resource "aws_vpc" "web_platform_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
    Project     = "ha-web-platform"
  }
}

# Create the first public subnet in AZ1 for high availability

resource "aws_subnet" "public_subnet_az1" {
  vpc_id                  = aws_vpc.web_platform_vpc.id
  cidr_block              = var.public_subnet1_cidr
  availability_zone       = var.az1
  map_public_ip_on_launch = true
  tags = {
    Name        = "${var.environment}-public-subnet-az1"
    Environment = var.environment
    Project     = "ha-web-platform"
  }
}

# Create the second public subnet in AZ2 for high availability

resource "aws_subnet" "public_subnet_az2" {
  vpc_id                  = aws_vpc.web_platform_vpc.id
  cidr_block              = var.public_subnet2_cidr
  availability_zone       = var.az2
  map_public_ip_on_launch = true
  tags = {
    Name        = "${var.environment}-public-subnet-az2"
    Environment = var.environment
    Project     = "ha-web-platform"
  }
}

# Create the Internet Gateway for outbound internet access

resource "aws_internet_gateway" "web_platform_igw" {
  vpc_id = aws_vpc.web_platform_vpc.id
  tags = {
    Name        = "${var.environment}-internet-gateway"
    Environment = var.environment
    Project     = "ha-web-platform"
  }
}

# Create the public route table

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.web_platform_vpc.id
  tags = {
    Name        = "${var.environment}-public-route-table"
    Environment = var.environment
    Project     = "ha-web-platform"
  }
}

# Add a default route to the Internet Gateway

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.web_platform_igw.id
}

# Associate the public route table with the first public subnet

resource "aws_route_table_association" "public1_assoc" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_route_table.id
}

# Associate the public route table with the second public subnet

resource "aws_route_table_association" "public2_assoc" {
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Create the Security Group for the ALB (allows HTTP from anywhere)

resource "aws_security_group" "alb_sg" {
  name        = "${var.environment}-alb-sg"
  description = "Allow HTTP from anywhere to ALB"
  vpc_id      = aws_vpc.web_platform_vpc.id

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

  tags = {
    Name        = "${var.environment}-alb-sg"
    Environment = var.environment
    Project     = "ha-web-platform"
  }
}


resource "aws_security_group" "ec2_sg" {
  name        = "${var.environment}-ec2-sg"
  description = "Allow HTTP only from ALB SG to EC2"
  vpc_id      = aws_vpc.web_platform_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-ec2-sg"
    Environment = var.environment
    Project     = "ha-web-platform"
  }
}


resource "aws_lb" "web_platform_alb" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]
  tags = {
    Name        = "${var.environment}-alb"
    Environment = var.environment
    Project     = "ha-web-platform"
  }
}

resource "aws_lb_target_group" "web_platform_tg" {
  name     = "${var.environment}-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.web_platform_vpc.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = {
    Name        = "${var.environment}-alb-tg"
    Environment = var.environment
    Project     = "ha-web-platform"
  }
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_platform_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_platform_tg.arn
  }
}


resource "aws_launch_template" "web_platform_lt" {
  name_prefix   = "${var.environment}-launch-template-"
  image_id      = var.ami_id != "" ? var.ami_id : data.aws_ami.latest_amazon_linux.id
  instance_type = var.instance_type
  user_data     = base64encode(file("user_data.sh"))
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-ec2-instance"
      Environment = var.environment
      Project     = "ha-web-platform"
    }
  }
}


resource "aws_autoscaling_group" "web_platform_asg" {
  name                      = "${var.environment}-asg"
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = [aws_subnet.public_subnet_az1.id, aws_subnet.public_subnet_az2.id]
  launch_template {
    id      = aws_launch_template.web_platform_lt.id
    version = "$Latest"
  }
  target_group_arns         = [aws_lb_target_group.web_platform_tg.arn]
  health_check_type         = "EC2"
  health_check_grace_period = 60
  tag {
    key                 = "Name"
    value               = "${var.environment}-ec2-instance"
    propagate_at_launch = true
  }
}


resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.environment}-cpu-alarm-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Alarm when CPU exceeds 70%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_platform_asg.name
  }
  alarm_actions = []
}

# ------------------- Persistence Layer -------------------
resource "aws_dynamodb_table" "web_platform_table" {
  name         = "${var.environment}-haweb-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
  tags = {
    Name        = "${var.environment}-haweb-table"
    Environment = var.environment
    Project     = "ha-web-platform"
  }
}
