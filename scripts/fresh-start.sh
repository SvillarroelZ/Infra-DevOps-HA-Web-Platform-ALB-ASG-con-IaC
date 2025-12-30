#!/usr/bin/env bash
# scripts/fresh-start.sh
# Complete deployment: cleanup, validate, deploy, verify
# Enhanced visual output with step-by-step progress

set -Eeuo pipefail

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "ERROR: Do not source this script. Run: bash scripts/fresh-start.sh" >&2
  return 1 2>/dev/null || exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

NON_INTERACTIVE="${NON_INTERACTIVE:-}"

show_usage() {
  cat <<'USAGE'
Usage:
  bash scripts/fresh-start.sh [options]

Options:
  --stack-name NAME          Stack name (default: ha-web-platform)
  --region REGION            AWS region (default: us-west-2)
  --environment dev|test|prod  Environment (default: dev)
  --instance-type TYPE       EC2 instance type (default: t2.micro)
  --desired-capacity N       ASG desired capacity (default: 2)
  --force                    Skip all confirmations
  -h, --help                 Show help.
USAGE
}

# Visual formatting helpers
print_header() {
  local title="$1"
  local width=60
  local line
  line=$(printf '%*s' "$width" '' | tr ' ' '=')
  printf "\n%b%s%b\n" "${BOLD}${CYAN}" "$line" "${RESET}"
  printf "%b  %s%b\n" "${BOLD}${CYAN}" "$title" "${RESET}"
  printf "%b%s%b\n\n" "${BOLD}${CYAN}" "$line" "${RESET}"
}

print_step() {
  local step="$1" title="$2"
  printf "\n%b=== STEP %s: %s ===%b\n\n" "${BOLD}${YELLOW}" "$step" "$title" "${RESET}"
}

print_kv() {
  local key="$1" value="$2"
  printf "  %b%-20s%b %s\n" "${BOLD}" "$key:" "${RESET}" "$value"
}

print_status() {
  local label="$1" status="$2"
  local color="$GREEN"
  [[ "$status" == "FAILED" || "$status" == *"FAILED"* || "$status" == *"ROLLBACK"* ]] && color="$RED"
  [[ "$status" == *"IN_PROGRESS"* ]] && color="$YELLOW"
  printf "  %b%-20s%b %b%s%b\n" "${BOLD}" "$label:" "${RESET}" "$color" "$status" "${RESET}"
}

print_progress() {
  local current="$1" max="$2" status="$3"
  local mins=$((current / 60))
  local secs=$((current % 60))
  local max_mins=$((max / 60))
  printf "  %b[%02d:%02d / %02d:00]%b %s\n" "${BOLD}" "$mins" "$secs" "$max_mins" "${RESET}" "$status"
}

# Defaults
STACK_NAME="ha-web-platform"
REGION="us-west-2"
ENVIRONMENT="dev"
INSTANCE_TYPE="t2.micro"
DESIRED="2"
FORCE="no"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack-name) STACK_NAME="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --environment) ENVIRONMENT="$2"; shift 2 ;;
    --instance-type) INSTANCE_TYPE="$2"; shift 2 ;;
    --desired-capacity) DESIRED="$2"; shift 2 ;;
    --force) FORCE="yes"; shift ;;
    -h | --help) show_usage; exit 0 ;;
    *) log_error "Unknown option: $1"; show_usage; exit 1 ;;
  esac
done

load_env

START_TIME=$(date +%s)

# ============================================================
# FRESH START DEPLOYMENT
# ============================================================
print_header "FRESH START DEPLOYMENT"

print_kv "Stack Name" "$STACK_NAME"
print_kv "Region" "$REGION"
print_kv "Environment" "$ENVIRONMENT"
print_kv "Instance Type" "$INSTANCE_TYPE"
print_kv "Desired Capacity" "$DESIRED"

if [[ "$FORCE" != "yes" ]]; then
  printf "\n  %bThis will:%b\n" "${BOLD}" "${RESET}"
  printf "    1. Delete any existing stack named '%s'\n" "$STACK_NAME"
  printf "    2. Validate the CloudFormation template\n"
  printf "    3. Create a NEW stack with the parameters above\n"
  printf "    4. Verify the deployment\n\n"
  
  printf "  %b*** WARNING: Existing resources will be DELETED ***%b\n\n" "${RED}${BOLD}" "${RESET}"
  
  if ! confirm_yes_no "Continue with fresh start?" "no"; then
    log_info "Deployment cancelled."
    exit 0
  fi
fi

# ============================================================
# STEP 1: CLEANUP
# ============================================================
print_step "1/4" "CLEANUP OLD RESOURCES"

status=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null || echo "DOES_NOT_EXIST")

case "$status" in
  DOES_NOT_EXIST)
    log_success "No existing stack found - starting fresh!"
    ;;
  DELETE_IN_PROGRESS | DELETE_COMPLETE)
    log_info "Stack deletion already in progress. Waiting..."
    WAIT_TIME=0
    MAX_WAIT=600  # 10 minutes
    
    while [ $WAIT_TIME -lt $MAX_WAIT ]; do
      status=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "DOES_NOT_EXIST")
      
      if [[ "$status" == "DOES_NOT_EXIST" || "$status" == "DELETE_COMPLETE" ]]; then
        log_success "Stack deleted successfully."
        break
      fi
      
      if (( WAIT_TIME % 15 == 0 )); then
        print_progress "$WAIT_TIME" "$MAX_WAIT" "$status"
      fi
      
      sleep 5
      WAIT_TIME=$((WAIT_TIME + 5))
    done
    ;;
  *)
    print_status "Current Status" "$status"
    log_info "Deleting existing stack..."
    
    bash "$SCRIPT_DIR/cleanup.sh" \
      --stack-name "$STACK_NAME" \
      --region "$REGION" \
      --force \
      --non-interactive || true
    
    log_info "Waiting for stack deletion..."
    WAIT_TIME=0
    MAX_WAIT=600  # 10 minutes
    
    while [ $WAIT_TIME -lt $MAX_WAIT ]; do
      status=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "DOES_NOT_EXIST")
      
      if [[ "$status" == "DOES_NOT_EXIST" || "$status" == "DELETE_COMPLETE" ]]; then
        log_success "Stack deleted successfully."
        break
      fi
      
      if (( WAIT_TIME % 15 == 0 )); then
        print_progress "$WAIT_TIME" "$MAX_WAIT" "$status"
      fi
      
      sleep 5
      WAIT_TIME=$((WAIT_TIME + 5))
    done
    
    if [ $WAIT_TIME -ge $MAX_WAIT ]; then
      log_error "Stack deletion timeout. Continuing anyway..."
    fi
    ;;
esac

# ============================================================
# STEP 2: VALIDATE TEMPLATE
# ============================================================
print_step "2/4" "VALIDATE TEMPLATE"

TEMPLATE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)/iac/main.yaml"
print_kv "Template" "$TEMPLATE_PATH"

if ! aws cloudformation validate-template \
  --template-body file://"$TEMPLATE_PATH" \
  --region "$REGION" >/dev/null 2>&1; then
  log_error "Template validation failed!"
  exit 1
fi

log_success "Template is valid."

# ============================================================
# STEP 3: DEPLOY
# ============================================================
print_step "3/4" "DEPLOY NEW STACK"

bash "$SCRIPT_DIR/deploy.sh" \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --environment "$ENVIRONMENT" \
  --instance-type "$INSTANCE_TYPE" \
  --desired-capacity "$DESIRED" \
  --image-id "${AMI_ID:-ami-022bee044edfca8f1}" \
  --vpc-cidr "${VPC_CIDR:-10.0.0.0/16}" \
  --public-subnet-1-cidr "${PUBLIC_SUBNET_1_CIDR:-10.0.1.0/24}" \
  --public-subnet-2-cidr "${PUBLIC_SUBNET_2_CIDR:-10.0.2.0/24}" \
  --private-subnet-1-cidr "${PRIVATE_SUBNET_1_CIDR:-10.0.11.0/24}" \
  --private-subnet-2-cidr "${PRIVATE_SUBNET_2_CIDR:-10.0.12.0/24}" \
  --non-interactive \
  --yes

# ============================================================
# STEP 4: FINAL STATUS
# ============================================================
print_step "4/4" "FINAL STATUS"

status=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null || echo "UNKNOWN")

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
TOTAL_MINS=$((TOTAL_TIME / 60))
TOTAL_SECS=$((TOTAL_TIME % 60))

print_status "Stack Status" "$status"
print_kv "Total Duration" "${TOTAL_MINS}m ${TOTAL_SECS}s"

if [[ "$status" == "CREATE_COMPLETE" || "$status" == "UPDATE_COMPLETE" ]]; then
  # Get ALB DNS
  ALB_DNS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='HaWebAlbDnsName'].OutputValue" \
    --output text 2>/dev/null || echo "N/A")
  
  print_header "DEPLOYMENT SUCCESSFUL"
  
  printf "  %bApplication URL:%b\n" "${BOLD}" "${RESET}"
  printf "  %bhttp://%s%b\n\n" "${GREEN}" "$ALB_DNS" "${RESET}"
  
  printf "  %bNext Steps:%b\n" "${BOLD}" "${RESET}"
  printf "    1. Verify:   %bbash scripts/verify.sh --yes%b\n" "${CYAN}" "${RESET}"
  printf "    2. Evidence: %bbash scripts/evidence.sh --yes%b\n" "${CYAN}" "${RESET}"
  printf "    3. Destroy:  %bbash scripts/destroy.sh%b\n\n" "${RED}" "${RESET}"
  
  log_success "Fresh start deployment completed successfully!"
else
  print_header "DEPLOYMENT STATUS"
  log_warn "Stack is in state: $status"
  log_info "Check events with:"
  printf "  aws cloudformation describe-stack-events --stack-name %s --region %s\n\n" "$STACK_NAME" "$REGION"
fi

exit 0
