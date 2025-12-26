# Architecture Deep Dive

## Overview

This document provides a detailed explanation of the architecture, design decisions, and AWS resource relationships for the HA Web Platform project.

## Components
- VPC, Subnets, IGW, Route Table
- Security Groups (ALB, EC2)
- Application Load Balancer (ALB)
- Auto Scaling Group (ASG) with Launch Template
- EC2 Instances (serving instance metadata)
- CloudWatch Alarm

## Security
- No SSH open to the world
- Only HTTP via ALB
- EC2 only accessible from ALB SG
- SSM option explained (if available)

## External Lab/Integration Connections
- Any external endpoints, tokens, or lab-specific variables must be declared in a `.env` file (see `.env.example`).
- Never commit real credentials or secrets to the repository.
- Scripts and code should load variables from `.env` using standard tools (e.g., `source .env` in bash).
- Document all required variables in `.env.example` and README.md.

## Diagrams
- (Insert Mermaid or ASCII diagram here)
