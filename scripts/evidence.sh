#!/usr/bin/env bash
# scripts/evidence.sh
# Capture evidence: stack outputs, ALB health, DynamoDB operations
# Enhanced visual output for clarity and readability

set -Eeuo pipefail

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "ERROR: Do not source this script. Run: bash scripts/evidence.sh" >&2
  return 1 2>/dev/null || exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

show_usage() {
  cat <<'USAGE'
Usage:
  bash scripts/evidence.sh [options]

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
LOG_DIR="${REPO_ROOT}/logs/evidence"
LOG_FILE="${LOG_DIR}/evidence.log"
ensure_dir "$LOG_DIR"
append_log "$LOG_FILE" "Evidence started"

require_aws_cli
load_env
require_cmd jq || log_warn "jq not found. DynamoDB item read/write may be limited."

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

STACK_NAME_VAL="$(pick_value "$STACK_NAME_ARG" "${STACK_NAME:-}" "$DEFAULT_STACK_NAME" "Stack name")"
REGION_VAL="$(pick_value "$REGION_ARG" "${AWS_REGION:-}" "$DEFAULT_REGION" "AWS region")"

log_info ""
log_info "Capturing evidence from CloudFormation stack..."
log_info "Log file: $LOG_FILE"
log_info ""

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
  [[ "$status" == "FAILED" || "$status" == "ERROR" ]] && color="$RED"
  [[ "$status" == "PENDING" || "$status" == "IN_PROGRESS" ]] && color="$YELLOW"
  printf "  %b%-24s%b %b%s%b\n" "${BOLD}" "$label:" "${RESET}" "$color" "$status" "${RESET}"
}

if [[ "$ASSUME_YES" != "yes" && "$NON_INTERACTIVE" != "yes" ]]; then
  if ! confirm_yes_no "Continue with evidence capture?" "yes"; then
    log_warn "Evidence capture cancelled by user."
    exit 0
  fi
fi

if ! stack_exists "$STACK_NAME_VAL" "$REGION_VAL"; then
  log_error "Stack not found: ${STACK_NAME_VAL} in ${REGION_VAL}"
  log_info "Did you run deploy.sh? Are you using the correct region?"
  exit 1
fi

# Fetch all stack data once
STACK_JSON=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME_VAL" --region "$REGION_VAL" --output json 2>/dev/null)

# ============================================================
# STEP 1: Stack Summary Dashboard
# ============================================================
print_header "STEP 1: STACK SUMMARY"

STACK_STATUS=$(echo "$STACK_JSON" | jq -r '.Stacks[0].StackStatus')
STACK_ID=$(echo "$STACK_JSON" | jq -r '.Stacks[0].StackId')
CREATION_TIME=$(echo "$STACK_JSON" | jq -r '.Stacks[0].CreationTime')
DESCRIPTION=$(echo "$STACK_JSON" | jq -r '.Stacks[0].Description // "N/A"')

print_subheader "Stack Information"
print_kv "Stack Name" "$STACK_NAME_VAL"
print_kv "Region" "$REGION_VAL"
print_status "Status" "$STACK_STATUS"
print_kv "Created" "$CREATION_TIME"
print_kv "Description" "$DESCRIPTION"

# Stack Outputs
print_subheader "Stack Outputs"
VPC_ID=$(echo "$STACK_JSON" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="HaWebVpcId") | .OutputValue // "N/A"')
ASG_NAME=$(echo "$STACK_JSON" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="HaWebAutoScalingGroupName") | .OutputValue // "N/A"')
DDB_NAME=$(echo "$STACK_JSON" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="HaWebDynamoDbTableName") | .OutputValue // "N/A"')
ALB_DNS=$(echo "$STACK_JSON" | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="HaWebAlbDnsName") | .OutputValue // "N/A"')

print_kv "VPC ID" "$VPC_ID"
print_kv "Auto Scaling Group" "$ASG_NAME"
print_kv "DynamoDB Table" "$DDB_NAME"
print_kv "ALB DNS" "$ALB_DNS"

# Stack Parameters (compact)
print_subheader "Stack Parameters"
echo "$STACK_JSON" | jq -r '.Stacks[0].Parameters[] | "  \(.ParameterKey): \(.ParameterValue)"'

# Log full JSON for detailed evidence
echo "$STACK_JSON" >> "$LOG_FILE"

# ============================================================
# STEP 2: Resource Inventory (Compact)
# ============================================================
print_header "STEP 2: RESOURCE INVENTORY"

RESOURCES_JSON=$(aws cloudformation describe-stack-resources --stack-name "$STACK_NAME_VAL" --region "$REGION_VAL" --output json 2>/dev/null)
RESOURCE_COUNT=$(echo "$RESOURCES_JSON" | jq '.StackResources | length')

print_subheader "Resources Created ($RESOURCE_COUNT total)"

# Group resources by type for cleaner display
printf "  %b%-40s %-20s %s%b\n" "${BOLD}" "LOGICAL ID" "TYPE" "STATUS" "${RESET}"
printf "  %s\n" "$(printf '%*s' 75 '' | tr ' ' '-')"

echo "$RESOURCES_JSON" | jq -r '.StackResources | sort_by(.ResourceType) | .[] | "\(.LogicalResourceId)|\(.ResourceType | split("::")[2])|\(.ResourceStatus)"' | \
while IFS='|' read -r logical_id res_type status; do
  status_color="$GREEN"
  [[ "$status" == *"FAILED"* ]] && status_color="$RED"
  [[ "$status" == *"PROGRESS"* ]] && status_color="$YELLOW"
  printf "  %-40s %-20s %b%s%b\n" "$logical_id" "$res_type" "$status_color" "$status" "${RESET}"
done

# Log resources JSON
echo "$RESOURCES_JSON" >> "$LOG_FILE"

# ============================================================
# STEP 3: ALB Health Check
# ============================================================
print_header "STEP 3: ALB HEALTH CHECK"

if [[ -n "$ALB_DNS" && "$ALB_DNS" != "N/A" && "$ALB_DNS" != "null" ]]; then
  URL="http://${ALB_DNS}/"
  
  print_subheader "Connectivity Test"
  print_kv "Endpoint" "$URL"
  
  set +e
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$URL" 2>/dev/null || echo "000")
  response_time=$(curl -s -o /dev/null -w "%{time_total}" --connect-timeout 10 "$URL" 2>/dev/null || echo "N/A")
  set -e
  
  if [[ "$http_code" == "200" ]]; then
    print_status "HTTP Status" "200 OK"
    print_kv "Response Time" "${response_time}s"
    log_success "ALB is responding correctly."
  elif [[ "$http_code" == "000" ]]; then
    print_status "HTTP Status" "CONNECTION FAILED"
    log_warn "Could not connect to ALB. Check security groups and target health."
  else
    print_status "HTTP Status" "$http_code"
    log_warn "ALB returned non-200 status."
  fi
  
  # Target Group Health
  print_subheader "Target Group Health"
  TG_ARN=$(aws elbv2 describe-target-groups --region "$REGION_VAL" --query "TargetGroups[?contains(TargetGroupName,'HaWeb')].TargetGroupArn" --output text 2>/dev/null | head -1)
  
  if [[ -n "$TG_ARN" ]]; then
    TARGETS_JSON=$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --region "$REGION_VAL" --output json 2>/dev/null)
    HEALTHY_COUNT=$(echo "$TARGETS_JSON" | jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State=="healthy")] | length')
    TOTAL_COUNT=$(echo "$TARGETS_JSON" | jq '.TargetHealthDescriptions | length')
    
    printf "  %b%-20s %-15s %s%b\n" "${BOLD}" "TARGET ID" "PORT" "HEALTH" "${RESET}"
    printf "  %s\n" "$(printf '%*s' 50 '' | tr ' ' '-')"
    
    echo "$TARGETS_JSON" | jq -r '.TargetHealthDescriptions[] | "\(.Target.Id)|\(.Target.Port)|\(.TargetHealth.State)"' | \
    while IFS='|' read -r target_id port health; do
      health_color="$GREEN"
      [[ "$health" != "healthy" ]] && health_color="$RED"
      printf "  %-20s %-15s %b%s%b\n" "$target_id" "$port" "$health_color" "$health" "${RESET}"
    done
    
    printf "\n"
    print_kv "Healthy Targets" "${HEALTHY_COUNT}/${TOTAL_COUNT}"
  else
    log_warn "Target group not found."
  fi
else
  log_warn "ALB DNS output not found. Skipping health check."
fi

# ============================================================
# STEP 4: DynamoDB Evidence
# ============================================================
print_header "STEP 4: DYNAMODB EVIDENCE"

if [[ -n "$DDB_NAME" && "$DDB_NAME" != "N/A" && "$DDB_NAME" != "null" ]]; then
  print_subheader "Table Information"
  
  DDB_JSON=$(aws dynamodb describe-table --table-name "$DDB_NAME" --region "$REGION_VAL" --output json 2>/dev/null)
  DDB_STATUS=$(echo "$DDB_JSON" | jq -r '.Table.TableStatus')
  DDB_BILLING=$(echo "$DDB_JSON" | jq -r '.Table.BillingModeSummary.BillingMode // "PROVISIONED"')
  DDB_ITEMS=$(echo "$DDB_JSON" | jq -r '.Table.ItemCount')
  DDB_SIZE=$(echo "$DDB_JSON" | jq -r '.Table.TableSizeBytes')
  DDB_ARN=$(echo "$DDB_JSON" | jq -r '.Table.TableArn')
  
  print_kv "Table Name" "$DDB_NAME"
  print_status "Status" "$DDB_STATUS"
  print_kv "Billing Mode" "$DDB_BILLING"
  print_kv "Item Count" "$DDB_ITEMS"
  print_kv "Size (bytes)" "$DDB_SIZE"
  print_kv "ARN" "$DDB_ARN"
  
  # Log full DynamoDB JSON
  echo "$DDB_JSON" >> "$LOG_FILE"
  
  # Test write/read
  if command -v jq >/dev/null 2>&1; then
    print_subheader "Write/Read Test"
    ITEM_ID="evidence-$(date +%s)"
    NOW_ISO="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    
    set +e
    aws dynamodb put-item \
      --table-name "$DDB_NAME" \
      --region "$REGION_VAL" \
      --item "{\"id\":{\"S\":\"${ITEM_ID}\"},\"timestamp\":{\"S\":\"${NOW_ISO}\"},\"message\":{\"S\":\"evidence-test\"}}" \
      --no-cli-pager >/dev/null 2>&1
    put_rc=$?
    
    ITEM_JSON=$(aws dynamodb get-item \
      --table-name "$DDB_NAME" \
      --region "$REGION_VAL" \
      --key "{\"id\":{\"S\":\"${ITEM_ID}\"}}" \
      --output json 2>/dev/null)
    get_rc=$?
    set -e
    
    print_kv "Test Item ID" "$ITEM_ID"
    print_kv "Timestamp" "$NOW_ISO"
    
    if (( put_rc == 0 && get_rc == 0 )); then
      print_status "Write" "SUCCESS"
      print_status "Read" "SUCCESS"
      log_success "DynamoDB write/read test passed."
    else
      print_status "Write/Read" "FAILED"
      log_warn "DynamoDB write/read failed. Check permissions."
    fi
    
    # Show existing items from EC2 instances
    print_subheader "Registered EC2 Instances"
    SCAN_JSON=$(aws dynamodb scan --table-name "$DDB_NAME" --region "$REGION_VAL" --output json 2>/dev/null)
    ITEM_COUNT=$(echo "$SCAN_JSON" | jq '.Items | length')
    
    if (( ITEM_COUNT > 0 )); then
      printf "  %b%-22s %-15s %-16s %s%b\n" "${BOLD}" "INSTANCE ID" "AZ" "PRIVATE IP" "LAUNCH TIME" "${RESET}"
      printf "  %s\n" "$(printf '%*s' 70 '' | tr ' ' '-')"
      
      echo "$SCAN_JSON" | jq -r '.Items[] | select(.id.S | startswith("i-")) | "\(.id.S)|\(.az.S // "N/A")|\(.private_ip.S // "N/A")|\(.launch_time.S // "N/A")"' | \
      while IFS='|' read -r inst_id az ip launch; do
        printf "  %-22s %-15s %-16s %s\n" "$inst_id" "$az" "$ip" "$launch"
      done
    else
      printf "  (No EC2 instances registered yet)\n"
    fi
  fi
else
  log_warn "DynamoDB table not found. Skipping evidence."
fi

# ============================================================
# SUMMARY
# ============================================================
print_header "EVIDENCE SUMMARY"

printf "  %b%-24s%b %s\n" "${BOLD}" "Stack:" "${RESET}" "$STACK_NAME_VAL"
printf "  %b%-24s%b " "${BOLD}" "Status:" "${RESET}"
if [[ "$STACK_STATUS" == "CREATE_COMPLETE" || "$STACK_STATUS" == "UPDATE_COMPLETE" ]]; then
  printf "%b%s%b\n" "${GREEN}" "HEALTHY" "${RESET}"
else
  printf "%b%s%b\n" "${YELLOW}" "$STACK_STATUS" "${RESET}"
fi
printf "  %b%-24s%b %s resources\n" "${BOLD}" "Resources:" "${RESET}" "$RESOURCE_COUNT"
printf "  %b%-24s%b %s\n" "${BOLD}" "Log File:" "${RESET}" "$LOG_FILE"
printf "\n"

log_success "Evidence capture completed."
append_log "$LOG_FILE" "Evidence finished"
exit 0
