#!/bin/bash
# user_data.sh - Bootstraps EC2 instances for the HA Web Platform.
# This script is executed at instance launch to install and configure Apache,
# and to display instance metadata on the default web page for validation and troubleshooting.

# Update all system packages to the latest version for security and stability.
sudo yum update -y

# Install Apache HTTP server to serve a simple web page.
sudo yum install -y httpd

# Enable Apache to start on boot and start the service immediately.
sudo systemctl enable httpd
sudo systemctl start httpd


# Create a professional index.html page with instance metadata and environment
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
HOSTNAME=$(hostname)
ENVIRONMENT="${environment:-dev}"
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title>HA Web Platform Instance</title>
	<style>
		body { font-family: Arial, sans-serif; background: #f4f6fa; color: #222; margin: 0; padding: 0; }
		.container { max-width: 600px; margin: 60px auto; background: #fff; border-radius: 10px; box-shadow: 0 2px 8px #0001; padding: 32px; }
		h1 { color: #2a5d9f; }
		.info { margin: 24px 0; font-size: 1.1em; }
		.footer { color: #888; font-size: 0.9em; margin-top: 32px; }
	</style>
</head>
<body>
	<div class="container">
		<h1>HA Web Platform Instance</h1>
		<div class="info">
			<strong>Instance ID:</strong> $INSTANCE_ID<br>
			<strong>Availability Zone:</strong> $AZ<br>
			<strong>Hostname:</strong> $HOSTNAME<br>
			<strong>Environment:</strong> $ENVIRONMENT
		</div>
		<p>This instance is part of a highly available, auto-scaled web platform deployed via Terraform.</p>
		<div class="footer">&copy; 2025 HA Web Platform Demo</div>
	</div>
</body>
</html>
EOF
