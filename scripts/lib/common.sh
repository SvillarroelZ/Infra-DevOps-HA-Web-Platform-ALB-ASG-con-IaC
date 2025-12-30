#!/usr/bin/env bash
# scripts/lib/common.sh
# Shared helpers for CloudFormation automation scripts

set -Eeuo pipefail

# Terminal colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

# Logging functions (all output to stderr to keep stdout clean for return values)
log_info()    { printf "%b[%s] [INFO] %s%b\n"    "${CYAN}" "$(timestamp)" "$1" "${RESET}" 1>&2; }
log_success() { printf "%b[%s] [OK]   %s%b\n"    "${GREEN}" "$(timestamp)" "$1" "${RESET}" 1>&2; }
log_warn()    { printf "%b[%s] [WARN] %s%b\n"    "${YELLOW}" "$(timestamp)" "$1" "${RESET}" 1>&2; }
log_error()   { printf "%b[%s] [ERROR] %s%b\n"   "${RED}" "$(timestamp)" "$1" "${RESET}" 1>&2; }

ensure_dir() { mkdir -p "$1"; }

append_log() {
  local file_path="$1" msg="$2"
  ensure_dir "$(dirname "$file_path")"
  printf "[%s] %s\n" "$(timestamp)" "$msg" >> "$file_path"
}

# Load environment variables from .env.aws-lab file
load_env() {
  local env_path=""
  if [[ -f ".env.aws-lab" ]]; then env_path=".env.aws-lab"
  elif [[ -f "env.aws-lab" ]]; then env_path="env.aws-lab"
  else env_path=""
  fi

  if [[ -z "$env_path" ]]; then
    log_warn "No .env.aws-lab file found. Using current AWS CLI configuration."
    return 0
  fi

  set -a
  # shellcheck disable=SC1090
  source "$env_path"
  set +a
  
  # Export AWS credentials for CLI
  export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
  export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
  export AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-}"
  export AWS_REGION="${AWS_REGION:-us-west-2}"
  
  log_success "Loaded environment from ${env_path}"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Missing dependency: ${cmd}"
    return 1
  fi
}

require_aws_cli() {
  require_cmd aws || { log_error "Install AWS CLI or use a Codespaces image that includes it."; exit 1; }
}

prompt_text() {  # Single-line text prompt, returns default if empty
  local label="$1" default_value="$2" input=""
  printf "%b%s%b [%bdefault: %s%b] (press Enter for default): " "${BOLD}${CYAN}" "$label" "${RESET}" "${YELLOW}" "$default_value" "${RESET}" >&2
  IFS= read -r input < /dev/stdin || true
  if [[ -z "$input" ]]; then
    printf "%s" "$default_value"
  else
    printf "%s" "$input"
  fi
}

prompt_choice() {  # Numbered menu, returns selected option string
  local label="$1" default_index="$2"; shift 2
  local options=("$@") input="" i

  printf "%b%s%b\n" "${BOLD}${CYAN}" "$label" "${RESET}" >&2
  for i in "${!options[@]}"; do
    printf "  %b%2d%b  %s\n" "${YELLOW}" "$((i+1))" "${RESET}" "${options[$i]}" >&2
  done

  printf "%bSelect 1-%d%b [%bdefault: %s%b] (press Enter for default): " "${BOLD}${CYAN}" "${#options[@]}" "${RESET}" "${YELLOW}" "$default_index" "${RESET}" >&2
  IFS= read -r input || true
  if [[ -z "$input" ]]; then input="$default_index"; fi

  if ! [[ "$input" =~ ^[0-9]+$ ]]; then
    log_warn "Invalid selection. Using default."
    input="$default_index"
  fi
  if (( input < 1 || input > ${#options[@]} )); then
    log_warn "Selection out of range. Using default."
    input="$default_index"
  fi

  printf "%s" "${options[$((input-1))]}"
}

confirm_yes_no() {
  local label="$1" default_yes="$2" input=""
  local hint="y/N"
  local action_hint="type 'y' and Enter to confirm, or just Enter for No"
  if [[ "$default_yes" == "yes" ]]; then
    hint="Y/n"
    action_hint="press Enter to confirm, or type 'n' to cancel"
  fi
  printf "%b%s%b (%s) - %s: " "${BOLD}${CYAN}" "$label" "${RESET}" "$hint" "$action_hint" >&2
  IFS= read -r input || true
  if [[ -z "$input" ]]; then
    [[ "$default_yes" == "yes" ]] && return 0 || return 1
  fi
  case "$input" in
    y|Y|yes|YES) return 0 ;;
    n|N|no|NO) return 1 ;;
    *) [[ "$default_yes" == "yes" ]] && return 0 || return 1 ;;
  esac
}

aws_hint_common() {  # Print troubleshooting hints for AWS CLI issues
  log_info "Hints:"
  log_info "  - Check AWS credentials: aws sts get-caller-identity"
  log_info "  - Check region: export AWS_REGION=us-west-2"
  log_info "  - If using a lab role, permissions may be restricted."
}

aws_try_validate_template() {
  local template_path="$1" region="$2"
  if ! out=$(aws cloudformation validate-template --region "$region" --template-body "file://${template_path}" --no-cli-pager 2>&1); then
    log_error "Template validation failed."
    printf "%b%s%b\n" "${RED}" "$out" "${RESET}" 1>&2
    log_info "Review template path: ${template_path}"
    aws_hint_common
    return 1
  fi
  return 0
}

get_stack_status() {
  local stack_name="$1" region="$2"
  aws cloudformation describe-stacks --stack-name "$stack_name" --region "$region" --query "Stacks[0].StackStatus" --output text 2>/dev/null || true
}

stack_exists() {
  local stack_name="$1" region="$2"
  aws cloudformation describe-stacks --stack-name "$stack_name" --region "$region" --query "Stacks[0].StackStatus" --output text >/dev/null 2>&1
}

print_failed_stack_events() {
  local stack_name="$1" region="$2"
  aws cloudformation describe-stack-events \
    --stack-name "$stack_name" \
    --region "$region" \
    --max-items 50 \
    --query "StackEvents[?ResourceStatus=='UPDATE_FAILED' || ResourceStatus=='CREATE_FAILED' || ResourceStatus=='DELETE_FAILED'].[Timestamp,LogicalResourceId,ResourceType,ResourceStatusReason]" \
    --output table --no-cli-pager || true
}

select_stack_from_dynamodb() {  # Interactive stack picker from DynamoDB catalog
  local region="$1"
  require_cmd jq || return 1

  local table="haweb-stack-catalog"
  local stacks_json
  stacks_json=$(aws dynamodb scan \
    --table-name "$table" \
    --region "$region" \
    --filter-expression "#et = :created" \
    --expression-attribute-names '{"#et":"event_type"}' \
    --expression-attribute-values '{":created":{"S":"created"}}' \
    --output json 2>/dev/null || true)

  if [[ -z "$stacks_json" || "$stacks_json" == "{}" ]]; then
    return 1
  fi
  local len
  len=$(printf "%s" "$stacks_json" | jq '.Items | length' 2>/dev/null || echo 0)
  if [[ "$len" == "0" ]]; then
    return 1
  fi

  local stack_names prefixes envs i
  mapfile -t stack_names < <(printf "%s" "$stacks_json" | jq -r '.Items[].stack_name.S')
  mapfile -t prefixes    < <(printf "%s" "$stacks_json" | jq -r '.Items[].resource_prefix.S')
  mapfile -t envs        < <(printf "%s" "$stacks_json" | jq -r '.Items[].environment.S')

  log_info "Stacks found in DynamoDB catalog:"
  for i in "${!stack_names[@]}"; do
    printf "  %b%2d%b  %s (prefix=%s env=%s)\n" "${YELLOW}" "$((i+1))" "${RESET}" "${stack_names[$i]}" "${prefixes[$i]}" "${envs[$i]}"
  done

  local sel
  sel=$(prompt_text "Select stack number" "1")
  if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#stack_names[@]} )); then
    log_warn "Invalid stack selection."
    return 1
  fi
  SELECTED_STACK_NAME="${stack_names[$((sel-1))]}"
  return 0
}

is_cidr() {
  local cidr="$1"
  [[ "$cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]] || return 1
  local ip="${cidr%/*}" mask="${cidr#*/}" o
  IFS='.' read -r o1 o2 o3 o4 <<<"$ip"
  for o in "$o1" "$o2" "$o3" "$o4"; do
    [[ "$o" =~ ^[0-9]+$ ]] || return 1
    (( o >= 0 && o <= 255 )) || return 1
  done
  return 0
}

detect_sourced() {  # Returns 0 if script is sourced, 1 if executed
  local script="$0"
  [[ "$script" != /* ]] && script="$(cd "$(dirname "$script")" && pwd)/$(basename "$script")"
  [[ "${BASH_SOURCE[0]}" != "$script" ]] && return 0 || return 1
}
