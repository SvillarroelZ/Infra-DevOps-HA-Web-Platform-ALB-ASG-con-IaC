
#!/bin/bash
# deploy.sh - Deployment script for the HA Web Platform (CloudFormation)
#
# Abstract: This script automates the deployment of a highly available, secure, and auditable web platform on AWS. All comments are in English, concise, and line-based, explaining what and why each block exists.

# Exit immediately if a command exits with a non-zero status, treat unset variables as errors, and fail if any command in a pipeline fails
set -euo pipefail

# Function: get_latest_amazon_linux_2_ami
# Purpose: Retrieve the latest Amazon Linux 2 AMI ID for the specified AWS region
get_latest_amazon_linux_2_ami() {
  local region="$1" # The AWS region to search for the AMI
  aws ec2 describe-images \ # Query EC2 for available images
    --owners amazon \ # Only images owned by Amazon
    --region "$region" \ # Use the specified region
    --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \ # Filter for Amazon Linux 2 AMIs that are available
    --query 'Images[*].[ImageId,CreationDate]' \ # Get the ImageId and CreationDate
    --output json --no-cli-pager | \ # Output as JSON, disable CLI pager
    jq -r 'sort_by(.[1]) | last | .[0]' # Sort by creation date and select the latest ImageId
}

# Color definitions for CLI output for better readability
RED="\033[0;31m"   # Red text for errors
GREEN="\033[0;32m" # Green text for success
YELLOW="\033[1;33m" # Yellow text for warnings
CYAN="\033[0;36m"  # Cyan text for info
BOLD="\033[1m"     # Bold text
RESET="\033[0m"    # Reset text formatting

# Function: check_aws_cli_version
# Purpose: Ensure AWS CLI v2 is installed
check_aws_cli_version() {
  local version # Variable to hold the AWS CLI version
  version=$(aws --version 2>&1 | awk '{print $1}' | grep -oE '[0-9]+\.[0-9]+') # Extract version number
  if [[ -z "$version" || "${version%%.*}" -lt 2 ]]; then # Check if version is missing or less than 2
    echo -e "${RED}[ERROR] AWS CLI v2 is required. Please upgrade before running this script.${RESET}"
    exit 1
  fi
}

# Function: check_dependencies
# Purpose: Ensure all required command-line dependencies are installed
check_dependencies() {
  local missing=() # Array to hold missing dependencies
  for dep in aws cfn-lint jq curl; do # List of required dependencies
    command -v "$dep" &>/dev/null || missing+=("$dep") # Check if dependency is missing
  done
  if [ ${#missing[@]} -gt 0 ]; then # If any dependencies are missing
    echo -e "${RED}[ERROR] Missing dependencies: ${missing[*]}. Please install them before running this script.${RESET}"
    exit 1
  fi
}

# Function: validate_region
# Purpose: Allow only common lab regions for deployment
validate_region() {
  local region="$1" # The AWS region to validate
  case "$region" in
    us-east-1|us-west-2|eu-west-1|eu-central-1|ap-southeast-1|ap-northeast-1) return 0;; # Allowed regions
    *) echo -e "${RED}[ERROR] Region '$region' is not allowed for this lab. Use a common lab region (us-east-1, us-west-2, etc.).${RESET}"; exit 1;; # Disallowed region
  esac
}

# Function: validate_instance_type
# Purpose: Allow only free tier instance types
validate_instance_type() {
  local type="$1" # The instance type to validate
  case "$type" in
    t2.micro|t3.micro) return 0;; # Allowed instance types
    *) echo -e "${RED}[ERROR] Instance type '$type' is not allowed. Use t2.micro or t3.micro for free tier.${RESET}"; exit 1;; # Disallowed type
  esac
}

# --- Load AWS credentials and environment variables ---
# Check AWS CLI version and required dependencies before proceeding
check_aws_cli_version # Ensure AWS CLI v2 is installed
check_dependencies    # Ensure all required dependencies are present

# Load environment variables from .env.aws-lab if present, else from .env
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

# Check that AWS credentials are set in the environment
if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  echo -e "${RED}[ERROR] AWS credentials not found. Configure them in .env.aws-lab before continuing.${RESET}"
  exit 1
fi

# Validate AWS credentials by calling STS get-caller-identity
if ! aws sts get-caller-identity &>/dev/null; then
  echo -e "${RED}[ERROR] AWS credentials are invalid or expired. Please update your credentials and try again.${RESET}"
  exit 1
fi

# Set default values for region, AMI, and stack name, allowing override from environment

# Set default values for region, AMI, environment, and stack name, allowing override from environment
DEFAULT_REGION="${AWS_REGION:-us-west-2}"
DEFAULT_AMI="${AMI_ID:-ami-0c02fb55956c7d316}"
DEFAULT_ENVIRONMENT="${ENVIRONMENT:-dev}"
DEFAULT_DESIRED_CAPACITY="${DESIRED_CAPACITY:-2}"
DEFAULT_STACK_NAME="ha-web-platform"

# Prompt user to enter a custom stack name or use the default
echo -e "${CYAN}Default stack name is '${DEFAULT_STACK_NAME}'.${RESET}"
read -p "Press Enter to use this stack name or type another: " USER_STACK_NAME
if [ -n "$USER_STACK_NAME" ]; then
  STACK_NAME="$USER_STACK_NAME"
else
  STACK_NAME="$DEFAULT_STACK_NAME"
fi
export STACK_NAME


# Allow CLI overrides for environment and desired capacity
while [[ $# -gt 0 ]]; do
  case $1 in
    -s)
      STACK_NAME="$2"; shift 2;;
    -e)
      DEFAULT_ENVIRONMENT="$2"; shift 2;;
    -d)
      DEFAULT_DESIRED_CAPACITY="$2"; shift 2;;
    -h|--help)
      grep '^#' "$0" | cut -c 3-; exit 0;;
    *)
      echo -e "${RED}[ERROR] Unknown option: $1${RESET}" >&2; exit 1;;
  esac
done


# --- Region, instance type, environment, and desired capacity selection ---
echo -e "${CYAN}Default AWS region is '${DEFAULT_REGION}'.${RESET}"
read -p "Press Enter to use this region or type another AWS region (e.g., us-east-1): " USER_REGION
if [ -n "$USER_REGION" ]; then
  AWS_REGION="$USER_REGION"
else
  AWS_REGION="$DEFAULT_REGION"
fi
validate_region "$AWS_REGION"
export AWS_REGION

DEFAULT_INSTANCE_TYPE="t2.micro"
INSTANCE_TYPE="$DEFAULT_INSTANCE_TYPE"
read -p "Press Enter to use default instance type ($DEFAULT_INSTANCE_TYPE) or type another (t2.micro/t3.micro): " USER_TYPE
if [ -n "$USER_TYPE" ]; then
  INSTANCE_TYPE="$USER_TYPE"
fi
validate_instance_type "$INSTANCE_TYPE"

ENVIRONMENT="$DEFAULT_ENVIRONMENT"
read -p "Press Enter to use default environment ($DEFAULT_ENVIRONMENT) or type another (dev/test/prod): " USER_ENV
if [ -n "$USER_ENV" ]; then
  ENVIRONMENT="$USER_ENV"
fi

DESIRED_CAPACITY="$DEFAULT_DESIRED_CAPACITY"
read -p "Press Enter to use default desired capacity ($DEFAULT_DESIRED_CAPACITY) or type another (number): " USER_DESIRED
if [ -n "$USER_DESIRED" ]; then
  DESIRED_CAPACITY="$USER_DESIRED"
fi

# --- Find existing resources for this account/region to avoid duplication ---
echo -e "${CYAN}[INFO] Checking for existing resources in region $AWS_REGION for this account...${RESET}"
EXISTING_STACKS=$(aws cloudformation describe-stacks --region "$AWS_REGION" --query 'Stacks[*].StackName' --output text 2>/dev/null || true)
if echo "$EXISTING_STACKS" | grep -qw "$STACK_NAME"; then
  echo -e "${YELLOW}[WARN] A stack with the name '$STACK_NAME' already exists in region $AWS_REGION.${RESET}"
  echo -e "${YELLOW}Existing stacks: $EXISTING_STACKS${RESET}"
  read -p "Do you want to update this stack (y), delete and redeploy (d), or cancel (c)? [y/d/c] (default: c): " STACK_ACTION
  STACK_ACTION=$(echo "$STACK_ACTION" | tr '[:upper:]' '[:lower:]')
  if [[ -z "$STACK_ACTION" ]]; then STACK_ACTION="c"; fi
  echo "[You entered: $STACK_ACTION]"
  if [[ "$STACK_ACTION" == "d" ]]; then
    echo -e "${CYAN}[INFO] Deleting stack '$STACK_NAME'...${RESET}"
    aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$AWS_REGION"
    wait_for_stack_deletion "$STACK_NAME" "$AWS_REGION"
    STACK_STATUS="NOT_FOUND"
    echo -e "${GREEN}[SUCCESS] Stack deleted. You can now redeploy.${RESET}"
  elif [[ "$STACK_ACTION" == "y" ]]; then
    echo -e "${CYAN}[INFO] Updating existing stack '$STACK_NAME'...${RESET}"
  else
    echo -e "${CYAN}[INFO] Deployment cancelled by user.${RESET}"
    exit 0
  fi
fi

AMI_ID=$(get_latest_amazon_linux_2_ami "$AWS_REGION")
AMI_DESC="Latest Amazon Linux 2 AMI in $AWS_REGION ($AMI_ID)"

# --- Allow user to enter AMI manually if desired ---
echo -e "Default region selected. $AMI_DESC"
echo "1) Use default AMI ($AMI_ID)"
echo "2) Enter AMI manually"
read -p "Select option [1/2]: " AMI_OPTION
AMI_OPTION=${AMI_OPTION:-1}
if [[ "$AMI_OPTION" == "2" ]]; then
  read -p "Enter AMI ID: " AMI_ID
  AMI_DESC="Manual AMI ($AMI_ID)"
fi


# --- Show deployment summary and confirm ---
echo -e "\n${BOLD}Deployment summary:${RESET}"
echo -e "  Stack name:      ${GREEN}$STACK_NAME${RESET}"
echo -e "  AWS region:      ${GREEN}$AWS_REGION${RESET}"
echo -e "  AMI:             ${GREEN}$AMI_ID${RESET}"
echo -e "  AMI desc:        ${GREEN}$AMI_DESC${RESET}"
echo -e "  Instance type:   ${GREEN}$INSTANCE_TYPE${RESET}"
echo -e "  Environment:     ${GREEN}$ENVIRONMENT${RESET}"
echo -e "  DesiredCapacity: ${GREEN}$DESIRED_CAPACITY${RESET}"

# --- Prompt for deployment confirmation ---
confirm_prompt() {
  local prompt_text="$1"
  local default_answer="y"
  local user_input
  echo -en "$prompt_text [y/n] (default: y): "
  read user_input
  user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')
  if [[ -z "$user_input" ]]; then
    user_input="$default_answer"
  fi
  echo "[You entered: $user_input]"
  [[ "$user_input" == "y" ]]
}
if ! confirm_prompt "Proceed with deployment?"; then
  echo -e "${CYAN}[INFO] Deployment cancelled by user.${RESET}"
  exit 0
fi

# --- Validate template before deployment ---
TEMPLATE_FILE="$(dirname "$0")/../iac/main.yaml"
if ! command -v aws &> /dev/null; then
  echo -e "${RED}[ERROR] AWS CLI not found. Please install it before running this script.${RESET}"; exit 1
fi
if ! command -v cfn-lint &> /dev/null; then
  echo -e "${RED}[ERROR] cfn-lint not found. Please run: pip install -r requirements.txt${RESET}"; exit 1
fi
cfn-lint "$TEMPLATE_FILE" || { echo -e "${RED}[ERROR] Template validation failed.${RESET}"; exit 1; }

# --- Deploy or update the stack ---
echo -e "${CYAN}Starting deployment. This may take several minutes...${RESET}"

aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --parameter-overrides \
    Environment=$ENVIRONMENT \
    ImageId=$AMI_ID \
    InstanceType=$INSTANCE_TYPE \
    DesiredCapacity=$DESIRED_CAPACITY \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset

DEPLOY_EXIT=$?

wait_for_stack_completion "$STACK_NAME" "$AWS_REGION"

STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "UNKNOWN")

if [ "$STACK_STATUS" = "CREATE_COMPLETE" ] || [ "$STACK_STATUS" = "UPDATE_COMPLETE" ]; then
  echo -e "${GREEN}[SUCCESS] Deployment complete. Stack status: $STACK_STATUS${RESET}"
  echo -e "${CYAN}Stack: $STACK_NAME | Region: $AWS_REGION${RESET}"
  echo -e "View your stack in the AWS Console:"
  echo -e "  https://$AWS_REGION.console.aws.amazon.com/cloudformation/home?region=$AWS_REGION#/stacks/stackinfo?filteringText=$STACK_NAME"
  echo -e "${GREEN}All resources were created successfully!${RESET}"
  echo -e "${CYAN}You can now run ./scripts/verify.sh, ./scripts/evidence.sh, or ./scripts/destroy.sh for the next steps.${RESET}"
else
  echo -e "${RED}[ERROR] Deployment failed. Stack status: $STACK_STATUS${RESET}"
  echo -e "${CYAN}Fetching CloudFormation stack events for error details...${RESET}"
  aws cloudformation describe-stack-events --stack-name "$STACK_NAME" --region "$AWS_REGION" --max-items 10 \
    --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`ROLLBACK_IN_PROGRESS` || ResourceStatus==`ROLLBACK_FAILED` || ResourceStatus==`ROLLBACK_COMPLETE`].[Timestamp,ResourceType,LogicalResourceId,ResourceStatus,ResourceStatusReason]' \
    --output table --no-cli-pager || echo -e "${YELLOW}[WARN] Could not fetch stack events. Check your AWS credentials and permissions.${RESET}"
  echo -e "You can also view the stack and error details in the AWS Console:"
  echo -e "  https://$AWS_REGION.console.aws.amazon.com/cloudformation/home?region=$AWS_REGION#/stacks/stackinfo?filteringText=$STACK_NAME"
  echo -e "${YELLOW}Common causes: expired credentials, missing parameters, resource dependency errors. Review your template and try again.${RESET}"
  exit 1
fi

# --- Manual AWS CLI usage reminder ---
echo -e "${CYAN}If you want to run AWS CLI commands manually, first export your environment with:${RESET}"
echo -e "${BOLD}  set -a; . ./.env.aws-lab; set +a${RESET}"
echo -e "${CYAN}For normal use, just run the provided scripts. Manual export is only needed for advanced troubleshooting or custom AWS CLI commands.${RESET}"
