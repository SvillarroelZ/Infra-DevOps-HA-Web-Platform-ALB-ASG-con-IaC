echo -e "${CYAN}[INFO] Deleting stack '$STACK_NAME'...${RESET}"
echo -e "${CYAN}If you want to run AWS CLI commands manually, first export your environment with:${RESET}"
echo -e "${BOLD}  set -a; . ./.env.aws-lab; set +a${RESET}"
echo -e "${CYAN}For normal use, just run the provided scripts. Manual export is only needed for advanced troubleshooting or custom AWS CLI commands.${RESET}"



#!/bin/bash
# destroy.sh - Destruction script for the HA Web Platform (CloudFormation)
#
# Abstract: This script automates the safe destruction of all resources in the HA Web Platform. All comments are in English, concise, and line-based, explaining what and why each block exists.


# Seguridad y robustez: fail fast
set -euo pipefail

# Salidas colorizadas para mejor experiencia y troubleshooting
RED="\033[0;31m"   # Red text for errors
GREEN="\033[0;32m" # Green text for success
YELLOW="\033[1;33m" # Yellow text for warnings
CYAN="\033[0;36m"  # Cyan text for info
BOLD="\033[1m"     # Bold text
RESET="\033[0m"    # Reset text formatting

# Security & Compliance: Carga segura de variables de entorno
if [ -f .env.aws-lab ]; then
  set -a # Export all variables loaded from the file
  . ./.env.aws-lab # Source the environment file
  set +a # Stop exporting all variables
  echo -e "${CYAN}[INFO] Environment variables loaded from .env.aws-lab and exported globally${RESET}"
elif [ -f .env ]; then
  set -a
  . ./.env
  set +a
  echo -e "${CYAN}[INFO] Environment variables loaded from .env and exported globally${RESET}"
fi

# Security & Compliance: Validación de credenciales
if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  echo -e "${RED}[ERROR] AWS credentials not found. Configure them in .env.aws-lab before continuing.${RESET}"
  exit 1
fi

# Cloud Concepts: Permite personalización de stack para ambientes múltiples
DEFAULT_STACK_NAME="ha-web-platform" # Default CloudFormation stack name
echo -e "${CYAN}Default stack name is '${DEFAULT_STACK_NAME}'.${RESET}" # Inform user of the default stack name
read -p "Press Enter to use this stack name or type another: " USER_STACK_NAME # Prompt for custom stack name
if [ -n "$USER_STACK_NAME" ]; then
  STACK_NAME="$USER_STACK_NAME" # Use user-provided stack name
else
  STACK_NAME="$DEFAULT_STACK_NAME" # Use default stack name
fi
export STACK_NAME # Export stack name for use by child processes

# Technology: Verifica existencia antes de operar
EXISTING_STACKS=$(aws cloudformation describe-stacks --query 'Stacks[*].StackName' --output text 2>/dev/null || true) # List all stack names
if ! echo "$EXISTING_STACKS" | grep -qw "$STACK_NAME"; then
  echo -e "${YELLOW}[WARN] Stack '$STACK_NAME' does not exist. Nothing to delete.${RESET}" # Warn if stack does not exist
  exit 0
fi

# Security & Compliance: Confirmación interactiva para evitar errores
confirm_prompt() {
  local prompt_text="$1" # Prompt message
  local default_answer="y" # Default answer is yes
  local user_input # Variable for user input
  echo -en "$prompt_text [y/n] (default: y): " # Show prompt
  read user_input # Read input
  user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]') # Normalize
  if [[ -z "$user_input" ]]; then
    user_input="$default_answer" # Use default if empty
  fi
  echo "[You entered: $user_input]" # Echo input
  [[ "$user_input" == "y" ]] # Return true if yes
}
if ! confirm_prompt "Are you sure you want to delete stack '$STACK_NAME'?"; then
  echo -e "${CYAN}[INFO] Deletion cancelled by user.${RESET}" # Cancel if not confirmed
  exit 0
fi

# Technology: Espera interactiva y feedback visual
wait_for_stack_deletion() {
  local stack_name="$1" # Name of the stack to wait for
  local start_time end_time elapsed # Timing variables
  start_time=$(date +%s) # Record start time
  echo -ne "${CYAN}[INFO] Waiting for stack deletion to complete...${RESET}\n" # Notify user
  while true; do
    aws cloudformation describe-stacks --stack-name "$stack_name" &>/dev/null || break # Wait until stack is gone
    end_time=$(date +%s) # Update end time
    elapsed=$((end_time - start_time)) # Calculate elapsed time
    printf "\r[INFO] Elapsed: %02d:%02d ... still waiting for deletion..." $((elapsed/60)) $((elapsed%60)) # Show timer
    sleep 5 # Wait before next check
  done
  echo -e "\n${GREEN}[SUCCESS] Stack deleted: $stack_name${RESET}" # Success message
}


# Cloud Concepts & Billing: Destrucción y control de costos
# Billing & Pricing: Mensaje de éxito y advertencia final
echo -e "${GREEN}[SUCCESS] Infraestructura eliminada. No quedan recursos activos, evitando cargos innecesarios.${RESET}"
echo -e "${CYAN}[INFO] Deleting stack '$STACK_NAME'...${RESET}"
aws cloudformation delete-stack --stack-name "$STACK_NAME"
wait_for_stack_deletion "$STACK_NAME"

# Verify DynamoDB table deletion (should be deleted by CloudFormation)
DDB_TABLE_NAME=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='HaWebDynamoDbTableName'].OutputValue" --output text 2>/dev/null || true)
if [ -n "$DDB_TABLE_NAME" ]; then
  echo -e "${CYAN}[INFO] Verifying DynamoDB table deletion: $DDB_TABLE_NAME${RESET}"
  if aws dynamodb describe-table --table-name "$DDB_TABLE_NAME" &>/dev/null; then
    echo -e "${YELLOW}[WARN] DynamoDB table $DDB_TABLE_NAME still exists. Manual cleanup may be required.${RESET}"
  else
    echo -e "${GREEN}[SUCCESS] DynamoDB table $DDB_TABLE_NAME deleted successfully.${RESET}"
  fi
fi

# Reminder for manual AWS CLI usage with correct credentials
echo -e "${CYAN}If you want to run AWS CLI commands manually, first export your environment with:${RESET}" # Reminder
echo -e "${BOLD}  set -a; . ./.env.aws-lab; set +a${RESET}" # Show export command
echo -e "${CYAN}For normal use, just run the provided scripts. Manual export is only needed for advanced troubleshooting or custom AWS CLI commands.${RESET}" # Usage note
