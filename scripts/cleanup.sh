#!/usr/bin/env bash
# scripts/cleanup.sh
# Delete failed stacks in ROLLBACK_COMPLETE or DELETE_FAILED states
# Enhanced visual output

set -Eeuo pipefail

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "ERROR: Do not source this script. Run: bash scripts/cleanup.sh" >&2
  return 1 2>/dev/null || exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

NON_INTERACTIVE="${NON_INTERACTIVE:-}"

show_usage() {
  cat <<'USAGE'
Usage:
  bash scripts/cleanup.sh [options]

Options:
  --stack-name NAME          Stack name to delete (required)
  --region REGION            AWS region (default: us-west-2)
  --force                    Delete without confirmation
  --non-interactive          Don't prompt for confirmation
  -h, --help                 Show help.
USAGE
}

# Visual formatting helpers
print_header() {
  local title="$1"
  local width=60
  local line
  line=$(printf '%*s' "$width" '' | tr ' ' '=')
  printf "\n%b%s%b\n" "${BOLD}${YELLOW}" "$line" "${RESET}"
  printf "%b  %s%b\n" "${BOLD}${YELLOW}" "$title" "${RESET}"
  printf "%b%s%b\n\n" "${BOLD}${YELLOW}" "$line" "${RESET}"
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

# Defaults
STACK_NAME=""
REGION="us-west-2"
FORCE="no"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack-name) STACK_NAME="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --force) FORCE="yes"; shift ;;
    --non-interactive) NON_INTERACTIVE="yes"; shift ;;
    -h | --help) show_usage; exit 0 ;;
    *) log_error "Unknown option: $1"; show_usage; exit 1 ;;
  esac
done

# Validate required args
if [[ -z "$STACK_NAME" ]]; then
  log_error "Missing required option: --stack-name"
  show_usage
  exit 1
fi

load_env

# ============================================================
# CLEANUP UTILITY
# ============================================================
print_header "STACK CLEANUP UTILITY"

print_kv "Stack Name" "$STACK_NAME"
print_kv "Region" "$REGION"

# Check if stack exists
log_info "Checking stack status..."

status=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null || echo "DOES_NOT_EXIST")

if [[ "$status" == "DOES_NOT_EXIST" ]]; then
  printf "\n"
  log_success "Stack '$STACK_NAME' does not exist. Nothing to clean up."
  exit 0
fi

print_status "Current Status" "$status"

case "$status" in
  ROLLBACK_COMPLETE)
    log_warn "Stack is in ROLLBACK_COMPLETE state (failed creation)."
    ;;
  DELETE_FAILED)
    log_warn "Stack is in DELETE_FAILED state."
    ;;
  DELETE_IN_PROGRESS)
    log_info "Stack is already being deleted."
    exit 0
    ;;
  DELETE_COMPLETE)
    log_success "Stack has already been deleted."
    exit 0
    ;;
  *COMPLETE*)
    log_info "Stack appears to be healthy. Use destroy.sh instead."
    ;;
esac

# Confirm deletion
if [[ "$FORCE" != "yes" && "$NON_INTERACTIVE" != "yes" ]]; then
  printf "\n  %b*** WARNING: This action cannot be undone ***%b\n\n" "${RED}${BOLD}" "${RESET}"
  if ! confirm_yes_no "Delete stack '$STACK_NAME'?" "no"; then
    log_info "Deletion cancelled."
    exit 0
  fi
fi

# Delete stack
log_info "Deleting stack..."

set +e
delete_out=$(aws cloudformation delete-stack \
  --stack-name "$STACK_NAME" \
  --region "$REGION" 2>&1)
rc=$?
set -e

if (( rc != 0 )); then
  log_error "Failed to delete stack."
  printf "%b%s%b\n" "${RED}" "$delete_out" "${RESET}" 1>&2
  exit $rc
fi

log_success "Stack deletion initiated."
printf "\n"
print_kv "Next Step" "Wait for deletion or check status with:"
printf "  aws cloudformation describe-stacks --stack-name %s --region %s\n\n" "$STACK_NAME" "$REGION"

exit 0
