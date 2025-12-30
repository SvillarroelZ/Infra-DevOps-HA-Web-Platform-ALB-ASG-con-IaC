#!/usr/bin/env bash
# terraform/user_data.sh
# Bootstrap script for EC2 instances in the Auto Scaling Group.
# Rendered by Terraform templatefile() with variable substitution.
#
# This script:
#   1. Installs and starts Apache
#   2. Registers the instance in DynamoDB
#   3. Queries DynamoDB for all registered instances
#   4. Generates an HTML page showing instance info and all registered instances

set -euo pipefail

# Install Apache and jq
yum update -y
yum install -y httpd jq
systemctl enable httpd
systemctl start httpd

# Fetch instance metadata
INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
AZ="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
PRIVATE_IP="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
INSTANCE_TYPE="$(curl -s http://169.254.169.254/latest/meta-data/instance-type)"
HOSTNAME="$(hostname)"
LAUNCH_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Variables from Terraform templatefile()
ENVIRONMENT="${environment}"
RESOURCE_PREFIX="${resource_prefix}"
TABLE_NAME="${resource_prefix}-ddb"
AWS_REGION="${aws_region}"

# Register instance in DynamoDB
aws dynamodb put-item \
  --region "$AWS_REGION" \
  --table-name "$TABLE_NAME" \
  --item "{
    \"id\": {\"S\": \"$INSTANCE_ID\"},
    \"az\": {\"S\": \"$AZ\"},
    \"private_ip\": {\"S\": \"$PRIVATE_IP\"},
    \"instance_type\": {\"S\": \"$INSTANCE_TYPE\"},
    \"hostname\": {\"S\": \"$HOSTNAME\"},
    \"launch_time\": {\"S\": \"$LAUNCH_TIME\"},
    \"environment\": {\"S\": \"$ENVIRONMENT\"},
    \"status\": {\"S\": \"running\"}
  }" || echo "DynamoDB write failed - continuing anyway"

# Query DynamoDB for all registered instances
DDB_INSTANCES=$(aws dynamodb scan \
  --region "$AWS_REGION" \
  --table-name "$TABLE_NAME" \
  --query 'Items[*].[id.S,az.S,private_ip.S,launch_time.S]' \
  --output text 2>/dev/null || echo "")

# Build HTML table rows
INSTANCE_ROWS=""
while IFS=$'\t' read -r id az ip launch; do
  if [[ -n "$id" ]]; then
    INSTANCE_ROWS="$INSTANCE_ROWS<tr><td>$id</td><td>$az</td><td>$ip</td><td>$launch</td></tr>"
  fi
done <<< "$DDB_INSTANCES"

# Generate HTML page
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="refresh" content="30">
  <title>HA Web Platform - $RESOURCE_PREFIX</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
    .container { max-width: 900px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    h1 { color: #232f3e; border-bottom: 3px solid #ff9900; padding-bottom: 10px; }
    h2 { color: #232f3e; margin-top: 30px; }
    .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin: 20px 0; }
    .info-box { background: #f9f9f9; padding: 15px; border-radius: 5px; border-left: 4px solid #ff9900; }
    .info-box strong { color: #232f3e; display: block; margin-bottom: 5px; }
    .info-box span { color: #666; font-family: monospace; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th { background: #232f3e; color: white; padding: 12px; text-align: left; }
    td { padding: 10px; border-bottom: 1px solid #ddd; font-family: monospace; font-size: 0.9em; }
    tr:hover { background: #f5f5f5; }
    .status { display: inline-block; padding: 3px 10px; border-radius: 3px; background: #4caf50; color: white; }
    .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 0.9em; }
  </style>
</head>
<body>
  <div class="container">
    <h1>HA Web Platform</h1>
    <p><span class="status">Running</span> This instance is part of an Auto Scaling Group behind an Application Load Balancer.</p>
    
    <h2>Current Instance</h2>
    <div class="info-grid">
      <div class="info-box"><strong>Instance ID</strong><span>$INSTANCE_ID</span></div>
      <div class="info-box"><strong>Availability Zone</strong><span>$AZ</span></div>
      <div class="info-box"><strong>Private IP</strong><span>$PRIVATE_IP</span></div>
      <div class="info-box"><strong>Instance Type</strong><span>$INSTANCE_TYPE</span></div>
      <div class="info-box"><strong>Hostname</strong><span>$HOSTNAME</span></div>
      <div class="info-box"><strong>Launch Time</strong><span>$LAUNCH_TIME</span></div>
      <div class="info-box"><strong>Environment</strong><span>$ENVIRONMENT</span></div>
      <div class="info-box"><strong>Resource Prefix</strong><span>$RESOURCE_PREFIX</span></div>
    </div>
    
    <h2>DynamoDB Integration</h2>
    <div class="info-grid">
      <div class="info-box"><strong>Table Name</strong><span>$TABLE_NAME</span></div>
      <div class="info-box"><strong>Region</strong><span>$AWS_REGION</span></div>
    </div>
    
    <h2>All Registered Instances (from DynamoDB)</h2>
    <table>
      <tr><th>Instance ID</th><th>Availability Zone</th><th>Private IP</th><th>Launch Time</th></tr>
      $INSTANCE_ROWS
    </table>
    
    <div class="footer">
      <p><strong>Architecture:</strong> VPC with public/private subnets across 2 AZs | ALB | ASG | DynamoDB</p>
      <p>Page auto-refreshes every 30 seconds. Refresh the page to see load balancing across instances.</p>
    </div>
  </div>
</body>
</html>
EOF

# Create health check page
echo "OK" > /var/www/html/health.html
