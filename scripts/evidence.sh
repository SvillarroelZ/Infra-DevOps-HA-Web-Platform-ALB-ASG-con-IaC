#!/bin/bash
# evidence.sh - Collects stack outputs and helps gather evidence/screenshots for documentation
# Usage: ./evidence.sh [STACK_NAME]
# All outputs are in English for clarity and evidence collection.

set -euo pipefail
STACK_NAME=${1:-ha-web-platform}

# Get ALB DNS from stack outputs
ALB_DNS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='AlbDnsName'].OutputValue" --output text)

# Get VPC and Subnet IDs
VPC_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='VpcId'].OutputValue" --output text)
SUBNET1_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='PublicSubnet1Id'].OutputValue" --output text)
SUBNET2_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='PublicSubnet2Id'].OutputValue" --output text)

# Print outputs for screenshot/evidence
cat <<EOF
[INFO] Evidence for stack: $STACK_NAME
ALB DNS: $ALB_DNS
VPC ID: $VPC_ID
Public Subnet 1 ID: $SUBNET1_ID
Public Subnet 2 ID: $SUBNET2_ID

Take screenshots of the following:
- AWS Console: VPC, Subnets, ALB, ASG, CloudWatch Alarm
- Web page at http://$ALB_DNS/ (should show InstanceId and AZ)
- CloudFormation stack outputs and events
- Billing dashboard (to confirm cleanup)
EOF
