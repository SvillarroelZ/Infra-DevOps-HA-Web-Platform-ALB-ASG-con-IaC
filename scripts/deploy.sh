#!/usr/bin/env bash
# scripts/deploy.sh - Deploy CloudFormation stack
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_PATH="${REPO_ROOT}/iac/main.yaml"
LOG_DIR="${REPO_ROOT}/logs/deploy"
LOG_FILE="${LOG_DIR}/deploy.log"
ensure_dir "$LOG_DIR"

require_aws_cli
load_env

# Defaults from environment
CFN_STACK_NAME="${STACK_NAME:-ha-web-platform}"
AWS_DEPLOY_REGION="${AWS_REGION:-us-west-2}"
DEPLOY_ENVIRONMENT="${ENVIRONMENT:-dev}"
RESOURCE_PREFIX="${RESOURCE_PREFIX:-infra-ha-web-dev}"
EC2_INSTANCE_TYPE="${INSTANCE_TYPE:-t2.micro}"
ASG_DESIRED_CAPACITY="${DESIRED_CAPACITY:-2}"
ASG_MIN_SIZE="${MIN_SIZE:-2}"
ASG_MAX_SIZE="${MAX_SIZE:-2}"
VPC_CIDR_BLOCK="${VPC_CIDR:-10.0.0.0/16}"
PUBLIC_SUBNET_1_CIDR="${PUBLIC_SUBNET_1_CIDR:-10.0.1.0/24}"
PUBLIC_SUBNET_2_CIDR="${PUBLIC_SUBNET_2_CIDR:-10.0.2.0/24}"
PRIVATE_SUBNET_1_CIDR="${PRIVATE_SUBNET_1_CIDR:-10.0.11.0/24}"
PRIVATE_SUBNET_2_CIDR="${PRIVATE_SUBNET_2_CIDR:-10.0.12.0/24}"
EC2_AMI_ID="${IMAGE_ID:-ami-022bee044edfca8f1}"
DDB_ENDPOINT_ENABLED="${CREATE_DDB_VPC_ENDPOINT:-yes}"
ASSUME_YES="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) ASSUME_YES="yes"; shift ;;
    -h|--help) echo "Usage: bash scripts/deploy.sh [--yes]"; exit 0 ;;
    *) shift ;;
  esac
done

log_info "Stack: $CFN_STACK_NAME | Region: $AWS_DEPLOY_REGION"

if [[ "$ASSUME_YES" != "yes" ]]; then
  if ! confirm_yes_no "Continue with deployment?" "yes"; then
    log_warn "Deployment cancelled."
    exit 0
  fi
fi

log_info "Deploying CloudFormation stack..."
log_info "This typically takes 3-5 minutes. Please wait..."

set +e
aws cloudformation deploy \
  --template-file "$TEMPLATE_PATH" \
  --stack-name "$CFN_STACK_NAME" \
  --region "$AWS_DEPLOY_REGION" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides \
    ResourcePrefix="$RESOURCE_PREFIX" \
    Environment="$DEPLOY_ENVIRONMENT" \
    CreateDdbVpcEndpoint="$DDB_ENDPOINT_ENABLED" \
    VpcCidr="$VPC_CIDR_BLOCK" \
    PublicSubnet1Cidr="$PUBLIC_SUBNET_1_CIDR" \
    PublicSubnet2Cidr="$PUBLIC_SUBNET_2_CIDR" \
    PrivateSubnet1Cidr="$PRIVATE_SUBNET_1_CIDR" \
    PrivateSubnet2Cidr="$PRIVATE_SUBNET_2_CIDR" \
    InstanceType="$EC2_INSTANCE_TYPE" \
    DesiredCapacity="$ASG_DESIRED_CAPACITY" \
    MinSize="$ASG_MIN_SIZE" \
    MaxSize="$ASG_MAX_SIZE" \
    ImageId="$EC2_AMI_ID" \
  --no-fail-on-empty-changeset \
  --no-cli-pager 2>&1 | tee -a "$LOG_FILE"
rc=${PIPESTATUS[0]}
set -e

if (( rc != 0 )); then
  log_error "Deployment failed. Check logs: $LOG_FILE"
  exit $rc
fi

log_success "Deployment completed!"

# Show outputs
ALB_DNS=$(aws cloudformation describe-stacks --stack-name "$CFN_STACK_NAME" --region "$AWS_DEPLOY_REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='HaWebAlbDnsName'].OutputValue" --output text 2>/dev/null)
log_info "ALB URL: http://${ALB_DNS}"
log_info "Next: bash scripts/verify.sh --yes"
