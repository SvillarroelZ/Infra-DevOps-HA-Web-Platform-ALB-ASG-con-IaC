#!/bin/bash
# deploy.sh - Deploys the HA Web Platform CloudFormation stack
# This script validates the template, checks for stack existence, and deploys idempotently.
# All outputs and errors are in English for clarity and evidence collection.

set -euo pipefail
STACK_NAME=${1:-ha-web-platform}
TEMPLATE_FILE="$(dirname "$0")/../iac/main.yaml"

# Validate template with cfn-lint for best practices
if ! command -v cfn-lint &> /dev/null; then
  echo "[ERROR] cfn-lint is not installed. Please run: pip install -r requirements.txt" >&2
  exit 1
fi

cfn-lint "$TEMPLATE_FILE" || { echo "[ERROR] Template validation failed." >&2; exit 1; }

# Check if stack exists
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" &> /dev/null; then
  echo "[INFO] Stack '$STACK_NAME' already exists. Updating..."
else
  echo "[INFO] Stack '$STACK_NAME' does not exist. Creating..."
fi

# Deploy stack (idempotent)
aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset

if [ $? -eq 0 ]; then
  echo "[SUCCESS] Deployment complete."
else
  echo "[ERROR] Deployment failed." >&2
  exit 1
fi
