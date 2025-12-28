echo -e "${CYAN}[INFO] Stack resources:${RESET}"
echo -e "${CYAN}If you want to run AWS CLI commands manually, first export your environment with:${RESET}"
echo -e "${BOLD}  set -a; . ./.env.aws-lab; set +a${RESET}"
echo -e "${CYAN}For normal use, just run the provided scripts. Manual export is only needed for advanced troubleshooting or custom AWS CLI commands.${RESET}"



#!/bin/bash
# verify.sh - Verification script for the HA Web Platform (CloudFormation)
#
# Abstract: This script verifies the deployment and status of all resources in the HA Web Platform. All comments are in English, concise, and line-based, explaining what and why each block exists.


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
  echo -e "${RED}[ERROR] Stack '$STACK_NAME' does not exist in this region. Nothing to verify.${RESET}" # Error if stack does not exist
  exit 1
fi

# Cloud Concepts & Technology: Estado del stack para troubleshooting
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND") # Get stack status
echo -e "${CYAN}[INFO] Stack '$STACK_NAME' status: ${BOLD}$STACK_STATUS${RESET}" # Show stack status


# Outputs para integración, troubleshooting y evidencia
echo -e "${CYAN}[INFO] Stack outputs:${RESET}"
aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs' --output table --no-cli-pager || echo -e "${YELLOW}[WARN] No outputs found.${RESET}"

# Outputs para evidencia y auditoría
echo -e "${CYAN}[INFO] Stack resources:${RESET}"
aws cloudformation describe-stack-resources --stack-name "$STACK_NAME" --output table --no-cli-pager || echo -e "${YELLOW}[WARN] No resources found.${RESET}"

# Security & Compliance: Evidencia de base de datos y persistencia
DDB_TABLE_NAME=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='HaWebDynamoDbTableName'].OutputValue" --output text)
if [ -n "$DDB_TABLE_NAME" ]; then
  echo -e "${CYAN}[INFO] Checking DynamoDB table: $DDB_TABLE_NAME${RESET}"
  aws dynamodb describe-table --table-name "$DDB_TABLE_NAME" --output table --no-cli-pager || echo -e "${YELLOW}[WARN] DynamoDB table not found or not yet available.${RESET}"
else
  echo -e "${YELLOW}[WARN] DynamoDB table output not found in stack outputs.${RESET}"
fi

# Technology: Recordatorio para troubleshooting avanzado
# Billing & Pricing: Advertencia de costos
echo -e "${YELLOW}[COST CONTROL] Recuerda destruir la infraestructura tras las pruebas para evitar cargos innecesarios. Usa ./scripts/destroy.sh para limpieza total.${RESET}"
# Evidence & Audit: Mensaje de evidencia
echo -e "${CYAN}[EVIDENCE] Todos los outputs y recursos pueden ser recolectados automáticamente para auditoría y portafolio usando ./scripts/evidence.sh${RESET}"
echo -e "${CYAN}If you want to run AWS CLI commands manually, first export your environment with:${RESET}" # Reminder
echo -e "${BOLD}  set -a; . ./.env.aws-lab; set +a${RESET}" # Show export command
echo -e "${CYAN}For normal use, just run the provided scripts. Manual export is only needed for advanced troubleshooting or custom AWS CLI commands.${RESET}" # Usage note
