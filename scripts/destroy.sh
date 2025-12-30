#!/usr/bin/env bash
# scripts/destroy.sh - Delete CloudFormation stack
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="${REPO_ROOT}/logs/destroy"
LOG_FILE="${LOG_DIR}/destroy.log"
ensure_dir "$LOG_DIR"

require_aws_cli
load_env

CFN_STACK_NAME="${STACK_NAME:-ha-web-platform}"
AWS_DEPLOY_REGION="${AWS_REGION:-us-west-2}"
ASSUME_YES="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) ASSUME_YES="yes"; shift ;;
    -h|--help) echo "Usage: bash scripts/destroy.sh [--yes]"; exit 0 ;;
    *) shift ;;
  esac
done

if ! stack_exists "$CFN_STACK_NAME" "$AWS_DEPLOY_REGION"; then
  log_warn "Stack $CFN_STACK_NAME does not exist."
  exit 0
fi

log_info "Stack: $CFN_STACK_NAME | Region: $AWS_DEPLOY_REGION"

if [[ "$ASSUME_YES" != "yes" ]]; then
  if ! confirm_yes_no "Delete stack and all resources?" "no"; then
    log_warn "Deletion cancelled."
    exit 0
  fi
fi

log_info "Deleting stack..."
log_info "This typically takes 5-8 minutes. Please wait..."

aws cloudformation delete-stack --stack-name "$CFN_STACK_NAME" --region "$AWS_DEPLOY_REGION"

log_info "Waiting for deletion to complete..."
set +e
aws cloudformation wait stack-delete-complete --stack-name "$CFN_STACK_NAME" --region "$AWS_DEPLOY_REGION" 2>&1 | tee -a "$LOG_FILE"
rc=${PIPESTATUS[0]}
set -e

if (( rc != 0 )); then
  log_error "Deletion may have failed. Check AWS Console."
  exit $rc
fi

log_success "Stack deleted successfully!"
