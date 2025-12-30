#!/usr/bin/env bash
# scripts/menu.sh
# Interactive menu for deploy, verify, evidence, destroy operations
# Enhanced visual interface

set -Eeuo pipefail

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "ERROR: Do not source this script. Run: bash scripts/menu.sh" >&2
  return 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$REPO_ROOT/logs/menu"
LOG_FILE="$LOG_DIR/menu.log"
ensure_dir "$LOG_DIR"

cd "$REPO_ROOT"

# Visual formatting
print_banner() {
  local width=60
  local line
  line=$(printf '%*s' "$width" '' | tr ' ' '=')
  printf "\n%b%s%b\n" "${BOLD}${CYAN}" "$line" "${RESET}"
  printf "%b  HA WEB PLATFORM - AUTOMATION MENU%b\n" "${BOLD}${CYAN}" "${RESET}"
  printf "%b%s%b\n\n" "${BOLD}${CYAN}" "$line" "${RESET}"
  
  printf "  %bRepository:%b %s\n" "${BOLD}" "${RESET}" "$REPO_ROOT"
  printf "  %bLog File:%b   %s\n\n" "${BOLD}" "${RESET}" "$LOG_FILE"
}

print_menu() {
  printf "  %b%-4s%b %-45s\n" "${BOLD}${GREEN}" "[1]" "${RESET}" "Deploy or update infrastructure"
  printf "  %b%-4s%b %-45s\n" "${BOLD}${CYAN}" "[2]" "${RESET}" "Verify deployment"
  printf "  %b%-4s%b %-45s\n" "${BOLD}${YELLOW}" "[3]" "${RESET}" "Capture evidence"
  printf "  %b%-4s%b %-45s\n" "${BOLD}${RED}" "[4]" "${RESET}" "Destroy stack"
  printf "  %b%-4s%b %-45s\n" "${BOLD}${YELLOW}" "[5]" "${RESET}" "Show failed stack events"
  printf "  %b%-4s%b %-45s\n" "${BOLD}" "[6]" "${RESET}" "Exit"
  printf "\n"
}

print_banner

while true; do
  print_menu
  
  printf "  %bSelect option [1-6]:%b " "${BOLD}" "${RESET}"
  read -r choice
  
  case "$choice" in
    1)
      append_log "$LOG_FILE" "Started: Deploy infrastructure"
      printf "\n"
      bash "$SCRIPT_DIR/deploy.sh"
      append_log "$LOG_FILE" "Completed: Deploy infrastructure"
      printf "\n  %bPress Enter to return to menu...%b" "${BOLD}" "${RESET}"
      read -r
      print_banner
      ;;
    2)
      append_log "$LOG_FILE" "Started: Verify deployment"
      printf "\n"
      bash "$SCRIPT_DIR/verify.sh"
      append_log "$LOG_FILE" "Completed: Verify deployment"
      printf "\n  %bPress Enter to return to menu...%b" "${BOLD}" "${RESET}"
      read -r
      print_banner
      ;;
    3)
      append_log "$LOG_FILE" "Started: Capture evidence"
      printf "\n"
      bash "$SCRIPT_DIR/evidence.sh"
      append_log "$LOG_FILE" "Completed: Capture evidence"
      printf "\n  %bPress Enter to return to menu...%b" "${BOLD}" "${RESET}"
      read -r
      print_banner
      ;;
    4)
      append_log "$LOG_FILE" "Started: Destroy stack"
      printf "\n"
      bash "$SCRIPT_DIR/destroy.sh"
      append_log "$LOG_FILE" "Completed: Destroy stack"
      printf "\n  %bPress Enter to return to menu...%b" "${BOLD}" "${RESET}"
      read -r
      print_banner
      ;;
    5)
      load_env
      printf "\n"
      region="$(prompt_text "AWS region" "${AWS_REGION:-us-west-2}")"
      stack_name="$(prompt_text "Stack name" "${STACK_NAME:-ha-web-platform}")"
      printf "\n"
      print_failed_stack_events "$stack_name" "$region"
      printf "\n  %bPress Enter to return to menu...%b" "${BOLD}" "${RESET}"
      read -r
      print_banner
      ;;
    6)
      printf "\n"
      log_info "Exiting menu. Goodbye!"
      printf "\n"
      exit 0
      ;;
    *)
      log_warn "Invalid option '$choice'. Please select 1-6."
      sleep 1
      ;;
  esac
done
