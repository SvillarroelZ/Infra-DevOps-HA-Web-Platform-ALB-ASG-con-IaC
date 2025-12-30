#!/usr/bin/env python3
"""haweb_app.py

Optional Flask application for local development and testing.

Purpose:
    This module provides a dynamic web application that can be run locally
    in Codespaces or on a development machine. It demonstrates the same
    functionality as the static HTML served by the CloudFormation deployment.

Note:
    The CloudFormation/Terraform deployment uses Apache with static HTML
    because it works reliably under restricted AWS lab IAM policies.
    This Flask app is NOT deployed to EC2 instances.

Usage:
    pip install -r requirements.txt
    python app/haweb_app.py

Security:
    Never store AWS credentials in this file.
    Use environment variables or the lab role provided by the platform.
"""

import os
import socket
import logging

from flask import Flask, render_template_string
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "dev-secret-key")


def get_instance_metadata(path: str) -> str:
    """Fetch EC2 instance metadata. Returns 'N/A' if not on EC2."""
    try:
        import urllib.request
        url = f"http://169.254.169.254/latest/meta-data/{path}"
        with urllib.request.urlopen(url, timeout=1) as response:
            return response.read().decode("utf-8")
    except Exception:
        return "N/A (not on EC2)"


@app.route("/")
def index():
    """Main page showing instance metadata."""
    instance_id = get_instance_metadata("instance-id")
    availability_zone = get_instance_metadata("placement/availability-zone")
    private_ip = get_instance_metadata("local-ipv4")
    hostname = socket.gethostname()

    html = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>HA Web Platform</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            h1 { color: #232f3e; }
            table { border-collapse: collapse; margin-top: 20px; }
            td { padding: 8px 16px; border: 1px solid #ddd; }
            td:first-child { font-weight: bold; background: #f5f5f5; }
        </style>
    </head>
    <body>
        <h1>HA Web Platform</h1>
        <p>Flask Development Server</p>
        <table>
            <tr><td>Instance ID</td><td>{{ instance_id }}</td></tr>
            <tr><td>Availability Zone</td><td>{{ availability_zone }}</td></tr>
            <tr><td>Private IP</td><td>{{ private_ip }}</td></tr>
            <tr><td>Hostname</td><td>{{ hostname }}</td></tr>
            <tr><td>Environment</td><td>{{ environment }}</td></tr>
        </table>
    </body>
    </html>
    """

    logging.info(f"Request served: instance={instance_id}, az={availability_zone}")

    return render_template_string(
        html,
        instance_id=instance_id,
        availability_zone=availability_zone,
        private_ip=private_ip,
        hostname=hostname,
        environment=os.getenv("ENVIRONMENT", "development")
    )


@app.route("/health")
@app.route("/health.html")
def health():
    """Health check endpoint for load balancer."""
    return "OK", 200


if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    debug = os.getenv("FLASK_DEBUG", "false").lower() == "true"
    logging.info(f"Starting Flask app on port {port}")
    app.run(host="0.0.0.0", port=port, debug=debug)
