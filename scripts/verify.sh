#!/usr/bin/env bash
# scripts/verify.sh
# Verify deployment: stack status, ALB health, and target group status
# Enhanced visual output for clarity and readability

set -Eeuo pipefail

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "ERROR: Do not source this script. Run: bash scripts/verify.sh" >&2
  return 1 2>/dev/null || exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

show_usage() {
  cat <<'USAGE'
Usage:
  bash scripts/verify.sh [options]

Options:
  --stack-name NAME
  --region REGION
  --non-interactive        Do not prompt. Use args > env > defaults.
  --yes                    Skip confirmation (if any).
  -h, --help               Show help.

Environment variables:
  STACK_NAME, AWS_REGION
USAGE
}

DEFAULT_STACK_NAME="${STACK_NAME:-infra-ha-web-dev}"
DEFAULT_REGION="${AWS_REGION:-us-west-2}"
NON_INTERACTIVE="no"
ASSUME_YES="no"
STACK_NAME_ARG="" REGION_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack-name) STACK_NAME_ARG="${2:-}"; shift 2 ;;
    --region) REGION_ARG="${2:-}"; shift 2 ;;
    --non-interactive) NON_INTERACTIVE="yes"; shift ;;
    --yes) ASSUME_YES="yes"; shift ;;
    -h|--help) show_usage; exit 0 ;;
    *) log_error "Unknown option: $1"; show_usage; exit 2 ;;
  esac
done

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="${REPO_ROOT}/logs/verify"
LOG_FILE="${LOG_DIR}/verify.log"
ensure_dir "$LOG_DIR"
append_log "$LOG_FILE" "Verify started"

require_aws_cli
load_env

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

print_subheader() {
  local title="$1"
  printf "\n%b--- %s ---%b\n\n" "${BOLD}${YELLOW}" "$title" "${RESET}"
}

print_kv() {
  local key="$1" value="$2"
  printf "  %b%-24s%b %s\n" "${BOLD}" "$key:" "${RESET}" "$value"
}

print_status() {
  local label="$1" status="$2"
  local color="$GREEN"
  [[ "$status" == "FAILED" || "$status" == "ERROR" || "$status" == "unhealthy" ]] && color="$RED"
  [[ "$status" == "PENDING" || "$status" == *"IN_PROGRESS"* || "$status" == "initial" ]] && color="$YELLOW"
  printf "  %b%-24s%b %b%s%b\n" "${BOLD}" "$label:" "${RESET}" "$color" "$status" "${RESET}"
}

pick_value() {
  local arg="$1" envv="$2" def="$3" label="$4"
  local value="" origin=""
  if [[ -n "$arg" ]]; then value="$arg"; origin="args"
  elif [[ -n "$envv" ]]; then value="$envv"; origin="environment"
  else value="$def"; origin="default"
  fi

  if [[ "$NON_INTERACTIVE" == "yes" || -n "$arg" || -n "$envv" ]]; then
    log_info "${label}: ${value} (from ${origin})"
    printf "%s" "$value"
    return 0
  fi

  value="$(prompt_text "${label} (press Enter to use default)" "$def")"
  log_info "${label}: ${value} (selected)"
  printf "%s" "$value"
}

CFN_STACK_NAME="$(pick_value "$STACK_NAME_ARG" "${STACK_NAME:-}" "$DEFAULT_STACK_NAME" "Stack name")"
AWS_DEPLOY_REGION="$(pick_value "$REGION_ARG" "${AWS_REGION:-}" "$DEFAULT_REGION" "AWS region")"

# ============================================================
# VERIFICATION START
# ============================================================
print_header "DEPLOYMENT VERIFICATION"

print_subheader "Configuration"
print_kv "Stack Name" "$CFN_STACK_NAME"
print_kv "Region" "$AWS_DEPLOY_REGION"
print_kv "Log File" "$LOG_FILE"

if [[ "$ASSUME_YES" != "yes" && "$NON_INTERACTIVE" != "yes" ]]; then
  printf "\n"
  if ! confirm_yes_no "Continue with verification?" "yes"; then
    log_warn "Verification cancelled by user."
    exit 0
  fi
fi

if ! stack_exists "$CFN_STACK_NAME" "$AWS_DEPLOY_REGION"; then
  log_error "Stack not found: ${CFN_STACK_NAME} in ${AWS_DEPLOY_REGION}"
  log_info "Did you run deploy.sh? Are you using the correct region?"
  aws_hint_common
  exit 1
fi

# ============================================================
# STEP 1: STACK STATUS
# ============================================================
print_header "STEP 1: STACK STATUS"

STACK_JSON=$(aws cloudformation describe-stacks \
  --stack-name "$CFN_STACK_NAME" \
  --region "$AWS_DEPLOY_REGION" \
  --output json 2>/dev/null)

STACK_STATUS=$(echo "$STACK_JSON" | jq -r '.Stacks[0].StackStatus')
CREATION_TIME=$(echo "$STACK_JSON" | jq -r '.Stacks[0].CreationTime')
LAST_UPDATE=$(echo "$STACK_JSON" | jq -r '.Stacks[0].LastUpdatedTime // "N/A"')

print_subheader "Stack Information"
print_kv "Stack Name" "$CFN_STACK_NAME"
print_status "Status" "$STACK_STATUS"
print_kv "Created" "$CREATION_TIME"
print_kv "Last Updated" "$LAST_UPDATE"

# Stack Outputs
print_subheader "Stack Outputs"
VPC_ID=$(echo "$STACK_JSON" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="HaWebVpcId") | .OutputValue // "N/A"')
ASG_NAME=$(echo "$STACK_JSON" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="HaWebAutoScalingGroupName") | .OutputValue // "N/A"')
DDB_TABLE=$(echo "$STACK_JSON" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="HaWebDynamoDbTableName") | .OutputValue // "N/A"')
ALB_DNS=$(echo "$STACK_JSON" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="HaWebAlbDnsName") | .OutputValue // "N/A"')

print_kv "VPC ID" "$VPC_ID"
print_kv "Auto Scaling Group" "$ASG_NAME"
print_kv "DynamoDB Table" "$DDB_TABLE"
print_kv "ALB DNS" "$ALB_DNS"

if [[ "$STACK_STATUS" != *"COMPLETE"* || "$STACK_STATUS" == *"ROLLBACK"* ]]; then
  log_error "Stack is not in a healthy state: ${STACK_STATUS}"
  exit 1
fi

log_success "Stack status is healthy."

# ============================================================
# STEP 2: TARGET GROUP HEALTH
# ============================================================
print_header "STEP 2: TARGET GROUP HEALTH"

TG_ARN=$(aws elbv2 describe-target-groups \
  --region "$AWS_DEPLOY_REGION" \
  --query "TargetGroups[?contains(TargetGroupName,'HaWeb')].TargetGroupArn" \
  --output text 2>/dev/null | head -1)

if [[ -n "$TG_ARN" ]]; then
  print_subheader "Target Health Status"
  
  TARGETS_JSON=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --region "$AWS_DEPLOY_REGION" \
    --output json 2>/dev/null)
  
  HEALTHY_COUNT=$(echo "$TARGETS_JSON" | jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State=="healthy")] | length')
  TOTAL_COUNT=$(echo "$TARGETS_JSON" | jq '.TargetHealthDescriptions | length')
  
  printf "  %b%-22s %-10s %-15s %s%b\n" "${BOLD}" "TARGET ID" "PORT" "HEALTH" "REASON" "${RESET}"
  printf "  %s\n" "$(printf '%*s' 60 '' | tr ' ' '-')"
  
  echo "$TARGETS_JSON" | jq -r '.TargetHealthDescriptions[] | "\(.Target.Id)|\(.Target.Port)|\(.TargetHealth.State)|\(.TargetHealth.Reason // "-")"' | \
  while IFS='|' read -r target_id port health reason; do
    health_color="$GREEN"
    [[ "$health" != "healthy" ]] && health_color="$RED"
    [[ "$health" == "initial" ]] && health_color="$YELLOW"
    printf "  %-22s %-10s %b%-15s%b %s\n" "$target_id" "$port" "$health_color" "$health" "${RESET}" "$reason"
  done
  
  printf "\n"
  if (( HEALTHY_COUNT == TOTAL_COUNT && TOTAL_COUNT > 0 )); then
    log_success "All targets healthy: ${HEALTHY_COUNT}/${TOTAL_COUNT}"
  elif (( HEALTHY_COUNT > 0 )); then
    log_warn "Partial health: ${HEALTHY_COUNT}/${TOTAL_COUNT} targets healthy"
  else
    log_error "No healthy targets: ${HEALTHY_COUNT}/${TOTAL_COUNT}"
  fi
else
  log_warn "Target group not found."
fi

# ============================================================
# STEP 3: ALB CONNECTIVITY
# ============================================================
print_header "STEP 3: ALB CONNECTIVITY"

if [[ -z "$ALB_DNS" || "$ALB_DNS" == "N/A" || "$ALB_DNS" == "null" ]]; then
  log_error "ALB DNS output not found (HaWebAlbDnsName)."
  log_info "Check CloudFormation Outputs for the stack."
  exit 1
fi

URL="http://${ALB_DNS}/"

print_subheader "HTTP Health Check"
print_kv "Endpoint" "$URL"
append_log "$LOG_FILE" "HTTP check ${URL}"

printf "\n  %b%-10s %-8s %-12s %s%b\n" "${BOLD}" "ATTEMPT" "STATUS" "TIME" "RESULT" "${RESET}"
printf "  %s\n" "$(printf '%*s' 50 '' | tr ' ' '-')"

attempt=1
max_attempts=10
delay=2  # Exponential backoff: 2s, 4s, 8s...
start_ts=$(date +%s)

while (( attempt <= max_attempts )); do
  http_code="$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$URL" 2>/dev/null || echo "000")"
  now_ts=$(date +%s)
  elapsed=$((now_ts-start_ts))
  
  MINS=$((elapsed / 60))
  SECS=$((elapsed % 60))
  elapsed_str="${MINS}m ${SECS}s"
  
  if [[ "$http_code" == "200" ]]; then
    printf "  %-10s %b%-8s%b %-12s %bSUCCESS%b\n" "$attempt/$max_attempts" "${GREEN}" "$http_code" "${RESET}" "$elapsed_str" "${GREEN}" "${RESET}"
    
    append_log "$LOG_FILE" "HTTP ready in ${elapsed_str}"
    
    # Final success
    print_header "VERIFICATION COMPLETE"
    
    print_subheader "Results"
    print_status "Stack Status" "$STACK_STATUS"
    print_status "Target Health" "${HEALTHY_COUNT}/${TOTAL_COUNT} healthy"
    print_status "HTTP Status" "200 OK"
    print_kv "Total Time" "$elapsed_str"
    
    printf "\n  %bApplication URL:%b\n" "${BOLD}" "${RESET}"
    printf "  %bhttp://%s%b\n\n" "${GREEN}" "$ALB_DNS" "${RESET}"
    
    log_success "All verification checks passed!"
    exit 0
  elif [[ "$http_code" == "000" ]]; then
    printf "  %-10s %b%-8s%b %-12s Connection failed\n" "$attempt/$max_attempts" "${RED}" "---" "${RESET}" "$elapsed_str"
  else
    printf "  %-10s %b%-8s%b %-12s Waiting...\n" "$attempt/$max_attempts" "${YELLOW}" "$http_code" "${RESET}" "$elapsed_str"
  fi
  
  sleep "$delay"
  delay=$((delay * 2))
  (( delay > 30 )) && delay=30  # Cap at 30s
  attempt=$((attempt + 1))
done

end_ts=$(date +%s)
total=$((end_ts-start_ts))
TOTAL_MINS=$((total / 60))
TOTAL_SECS=$((total % 60))

print_header "VERIFICATION FAILED"

print_subheader "Status"
print_status "HTTP Check" "FAILED after ${TOTAL_MINS}m ${TOTAL_SECS}s"

print_subheader "Troubleshooting"
printf "  1. ALB/targets can take 2-3 minutes after deploy to become healthy\n"
printf "  2. Check Target Group health in EC2 console\n"
printf "  3. Verify Security Group rules allow traffic on port 80\n"
printf "  4. Re-run verify after a short wait\n"
printf "\n"

exit 1
