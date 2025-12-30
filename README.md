# High Availability Web Platform on AWS

[![AWS](https://img.shields.io/badge/AWS-CloudFormation-orange)](https://aws.amazon.com/cloudformation/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)
[![Español](https://img.shields.io/badge/Idioma-Español-red)](README_ES.md)

**Production-Ready Infrastructure as Code for Learning and Portfolio Demonstration**

---

## Table of Contents

1. [Overview](#overview)
2. [Why This Project](#why-this-project)
3. [Architecture](#architecture)
4. [Quick Start](#quick-start)
5. [Project Structure](#project-structure)
6. [Configuration](#configuration)
7. [Deployment Workflow](#deployment-workflow)
8. [Terraform Deployment Guide](#terraform-deployment-guide)
9. [Verification and Evidence](#verification-and-evidence)
10. [Screenshots](#screenshots)
11. [Security](#security)
12. [AWS Cloud Practitioner Domains](#aws-cloud-practitioner-domains)
13. [Script Output Examples](#script-output-examples)
14. [Troubleshooting](#troubleshooting)
15. [Downloads](#downloads)
16. [Lessons Learned](#lessons-learned)
17. [Repository Conventions](#repository-conventions)
18. [License](#license)

---

## Overview

This repository provides a complete, working example of a **highly available web platform** on AWS. It is designed for:

- **Students** learning cloud architecture and Infrastructure as Code
- **Professionals** building their DevOps portfolio with real, deployable code
- **Teams** needing a reference implementation for AWS best practices

Everything works out of the box. Clone the repository, add your AWS credentials, and deploy a production-grade infrastructure in under 15 minutes.

---

## Why This Project

Building cloud infrastructure is complex. This project solves common challenges:

| Challenge | Solution |
|-----------|----------|
| "I don't know where to start" | Step-by-step Quick Start guide with copy-paste commands |
| "My lab has restricted permissions" | Pre-configured for AWS Academy with LabInstanceProfile |
| "I need to prove my work" | Evidence collection scripts and 20 screenshots included |
| "I forget to delete resources" | Automated destroy scripts prevent unexpected charges |
| "I want to learn Terraform too" | Complete Terraform alternative with tutorial |
| "Interactive prompts confuse me" | All prompts show defaults; press Enter to accept |

### Key Features

| Feature | Description |
|---------|-------------|
| **Multi-AZ** | Resources span 2 Availability Zones for fault tolerance |
| **Auto Scaling** | EC2 instances scale 1-3 based on demand |
| **Application Load Balancer** | Layer 7 traffic distribution with health checks |
| **Private Subnets** | Application tier isolated from public internet |
| **DynamoDB** | Managed NoSQL with encryption at rest |
| **CloudWatch** | CPU utilization monitoring with alarms |
| **VPC Endpoint** | Optional private DynamoDB access |

---

## Architecture

### Infrastructure Diagram

```mermaid
flowchart TB
    subgraph AWS["AWS Region (us-west-2)"]
        subgraph VPC["VPC 10.0.0.0/16"]
            IGW[Internet Gateway]
            
            subgraph PublicTier["Public Subnets"]
                PUB1["Public Subnet 1<br/>10.0.1.0/24<br/>AZ1"]
                PUB2["Public Subnet 2<br/>10.0.2.0/24<br/>AZ2"]
                ALB["Application Load Balancer<br/>HTTP:80"]
                NAT["NAT Gateway"]
                EIP["Elastic IP"]
            end
            
            subgraph PrivateTier["Private Subnets"]
                PRIV1["Private Subnet 1<br/>10.0.11.0/24<br/>AZ1"]
                PRIV2["Private Subnet 2<br/>10.0.12.0/24<br/>AZ2"]
                ASG["Auto Scaling Group"]
                EC2A["EC2 Instance"]
                EC2B["EC2 Instance"]
            end
            
            subgraph DataTier["Data Layer"]
                DDB["DynamoDB Table<br/>Encryption: Enabled"]
                VPCE["VPC Endpoint<br/>(Optional)"]
            end
        end
        
        CW["CloudWatch Alarm<br/>CPU > 70%"]
    end
    
    Internet((Internet)) --> IGW
    IGW --> ALB
    ALB --> EC2A
    ALB --> EC2B
    EC2A --> NAT
    EC2B --> NAT
    NAT --> IGW
    ASG --> EC2A
    ASG --> EC2B
    EC2A -.-> VPCE
    EC2B -.-> VPCE
    VPCE --> DDB
    EC2A -.-> CW
    EC2B -.-> CW
```

### Network Layout

| Component | CIDR/Details | Purpose |
|-----------|--------------|---------|
| **VPC** | 10.0.0.0/16 | Isolated network container |
| **Public Subnet 1** | 10.0.1.0/24 (AZ1) | ALB, NAT Gateway |
| **Public Subnet 2** | 10.0.2.0/24 (AZ2) | ALB redundancy |
| **Private Subnet 1** | 10.0.11.0/24 (AZ1) | EC2 instances |
| **Private Subnet 2** | 10.0.12.0/24 (AZ2) | EC2 instances |

### Security Groups

| Security Group | Inbound | Outbound | Purpose |
|----------------|---------|----------|---------|
| **ALB SG** | HTTP:80 from 0.0.0.0/0 | All | Internet-facing load balancer |
| **EC2 SG** | HTTP:80 from ALB SG only | All | Private instances, no SSH |

### DynamoDB Integration

Each EC2 instance registers itself in DynamoDB on boot and displays all registered instances on the web page:

```mermaid
sequenceDiagram
    participant User
    participant ALB
    participant EC2
    participant DynamoDB

    Note over EC2: Instance boots via UserData
    EC2->>DynamoDB: put-item (instance_id, az, ip, timestamp)
    
    User->>ALB: HTTP GET /
    ALB->>EC2: Forward request
    EC2->>DynamoDB: scan (get all instances)
    DynamoDB-->>EC2: List of registered instances
    EC2-->>ALB: HTML with instance data
    ALB-->>User: Web page showing all instances
```

The web page displays:
- Current instance metadata (ID, AZ, private IP)
- DynamoDB table name
- All registered instances from DynamoDB scan
- Architecture summary

This demonstrates:
- EC2 to DynamoDB connectivity via VPC Endpoint (private, no internet)
- Instance awareness across the Auto Scaling Group
- Dynamic content generation from database queries

---

## Quick Start

### Overview of the Deployment Flow

```mermaid
flowchart LR
    A[1. Configure .env] --> B[2. Deploy]
    B --> C[3. Verify]
    C --> D[4. Use Application]
    D --> E[5. Collect Evidence]
    E --> F[6. Destroy]
```

| Step | Script | What It Does |
|------|--------|--------------|
| Configure | Manual | Create `.env.aws-lab` with your AWS credentials |
| Deploy | `fresh-start.sh` | Validates template, creates all AWS resources |
| Verify | `verify.sh` | Confirms stack is healthy, tests ALB endpoint |
| Use | Browser | Access web application via ALB DNS URL |
| Evidence | `evidence.sh` | Captures stack info, resources, and test results |
| Destroy | `destroy.sh` | Deletes all resources to avoid charges |

### Prerequisites

- AWS CLI v2 installed ([Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- AWS credentials with CloudFormation, EC2, ELB, DynamoDB permissions
- Bash 4.0+ (Linux/macOS/WSL)

### Lab Environment Compatibility

This project is designed for **AWS Lab environments** with restricted IAM permissions:

| Restriction | Solution |
|-------------|----------|
| Cannot create IAM Roles | Uses pre-existing **LabInstanceProfile** with **LabRole** |
| Instance types limited | Uses t2.micro/t3.micro (allowed) |
| Max 9 EC2 instances | ASG limited to 1-3 instances |
| DynamoDB reserved capacity disabled | Uses on-demand billing |
| VPC Endpoint may fail | Optional - set `CREATE_DDB_VPC_ENDPOINT=no` if needed |

### Step 1: Configure Environment

The `.env.aws-lab` file stores your AWS credentials and deployment parameters. This file is gitignored and never committed.

```bash
# Copy the example configuration
cp .env.aws-lab.example .env.aws-lab

# Edit with your credentials (use nano, vim, or VS Code)
nano .env.aws-lab
```

**Required variables** (get these from your AWS Academy Lab or IAM console):

```bash
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_SESSION_TOKEN=your-session-token    # Required for lab/temporary credentials
AWS_REGION=us-west-2
```

**Optional variables** (defaults are fine for most deployments):

```bash
STACK_NAME=ha-web-platform              # CloudFormation stack name
RESOURCE_PREFIX=infra-ha-web-dev        # Prefix for all resource names
INSTANCE_TYPE=t2.micro                  # EC2 instance type
DESIRED_CAPACITY=2                      # Number of EC2 instances
CREATE_DDB_VPC_ENDPOINT=yes             # Set to 'no' if endpoint creation fails
```

### Step 2: Deploy Infrastructure

```bash
# Recommended: Full deployment from scratch (skips confirmations)
bash scripts/fresh-start.sh --force

# Alternative: Interactive deployment (prompts for each parameter)
bash scripts/deploy.sh
```

**Expected output:**
```
[INFO] Step 1/3: Checking for existing stack...
[INFO] Step 2/3: Validating CloudFormation template...
[SUCCESS] Template is valid.
[INFO] Step 3/3: Deploying stack...
[INFO] Still deploying... (2m 30s / 15m 0s elapsed, status: CREATE_IN_PROGRESS)
[SUCCESS] Stack deployment completed. Final status: CREATE_COMPLETE
```

### Step 3: Verify Deployment

```bash
bash scripts/verify.sh
```

**Expected output:**
```
[SUCCESS] Stack ha-web-platform is in CREATE_COMPLETE state.
[INFO] ALB DNS: ha-web-platform-alb-123456789.us-west-2.elb.amazonaws.com
[SUCCESS] ALB is responding to HTTP requests (attempt 1/10, 0m 15s elapsed)
```

### Step 4: Collect Evidence

```bash
bash scripts/evidence.sh
```

Evidence is saved to `logs/evidence/` directory.

### Step 5: Destroy Infrastructure

```bash
bash scripts/destroy.sh
```

**Important**: Always destroy resources after testing to avoid charges.

---

## Project Structure

```
├── README.md                    # This file - unified documentation
├── .env.aws-lab                 # Configuration (credentials, parameters)
├── .env.aws-lab.example         # Configuration template
│
├── iac/
│   └── main.yaml                # CloudFormation template (UserData inline)
│
├── terraform/                   # Terraform alternative
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── user_data.sh
│
├── scripts/
│   ├── fresh-start.sh           # Full deployment orchestrator
│   ├── deploy.sh                # CloudFormation deployment
│   ├── verify.sh                # Health verification
│   ├── evidence.sh              # Evidence collection
│   ├── destroy.sh               # Stack deletion
│   ├── cleanup.sh               # Failed stack cleanup
│   ├── menu.sh                  # Interactive menu
│   └── lib/
│       └── common.sh            # Shared functions
│
├── logs/                        # All logs organized here
│   ├── .gitkeep                 # Preserves empty directories in git
│   ├── deploy/                  # Deployment logs
│   ├── destroy/                 # Destruction logs
│   ├── verify/                  # Verification logs
│   ├── evidence/                # Evidence files
│   └── menu/                    # Menu operation logs
│
├── app/                         # Application code
│   └── haweb_app.py             # Flask application (reference implementation)
│
└── docs/                        # Additional documentation
    └── screenshots/             # Evidence screenshots
```

---

## Configuration

### Environment Variables (.env.aws-lab)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `AWS_ACCESS_KEY_ID` | Yes | - | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Yes | - | AWS secret key |
| `AWS_SESSION_TOKEN` | Lab only | - | Temporary session token |
| `AWS_REGION` | Yes | us-west-2 | AWS region |
| `STACK_NAME` | No | ha-web-platform | CloudFormation stack name |
| `RESOURCE_PREFIX` | No | ha-web-platform | Resource naming prefix |
| `ENVIRONMENT` | No | dev | Environment tag (dev/test/prod) |
| `INSTANCE_TYPE` | No | t2.micro | EC2 instance type |
| `AMI_ID` | No | ami-022bee044edfca8f1 | Amazon Linux 2 AMI |
| `DESIRED_CAPACITY` | No | 2 | ASG desired instances |
| `MIN_SIZE` | No | 1 | ASG minimum instances |
| `MAX_SIZE` | No | 3 | ASG maximum instances |
| `VPC_CIDR` | No | 10.0.0.0/16 | VPC CIDR block |
| `CREATE_DDB_VPC_ENDPOINT` | No | yes | Create DynamoDB VPC endpoint |

### Parameter Priority

Scripts use this priority order:
1. **CLI arguments** (highest priority)
2. **Environment variables** (from .env.aws-lab)
3. **Default values** (fallback)

---

## Deployment Workflow

### Interactive vs Non-Interactive Mode

All scripts support both interactive and non-interactive modes:

| Mode | When Used | Behavior |
|------|-----------|----------|
| **Interactive** | Running in terminal | Prompts for confirmation, allows parameter changes |
| **Non-Interactive** | No TTY detected, or `--non-interactive` flag | Uses defaults or CLI arguments, no prompts |

### Understanding the Prompts

Every prompt tells you exactly what to do:

**Text input prompts:**
```
Stack name [default: ha-web-platform] (press Enter for default):
```
- Press Enter alone to use the default value shown in brackets
- Or type a new value and press Enter to override

**Confirmation prompts (default Yes):**
```
Continue with deployment? (Y/n) - press Enter to confirm, or type 'n' to cancel:
```
- The capital `Y` indicates Yes is the default
- Press Enter alone to accept and continue
- Type `n` and press Enter to cancel

**Confirmation prompts (default No):**
```
Continue? (y/N) - type 'y' and Enter to confirm, or just Enter for No:
```
- The capital `N` indicates No is the default
- Press Enter alone to cancel (safe default)
- Type `y` and press Enter to proceed

### Skip Confirmations

```bash
# Use --force to skip all confirmations
bash scripts/fresh-start.sh --force

# Use --yes to skip final confirmation only
bash scripts/deploy.sh --yes

# Use --non-interactive for CI/CD pipelines
bash scripts/deploy.sh --non-interactive --yes
```

### Automated Flow (fresh-start.sh)

```mermaid
flowchart LR
    A[Start] --> B{Existing Stack?}
    B -->|Yes| C[Delete Stack]
    B -->|No| D[Validate Template]
    C --> D
    D --> E[Deploy Stack]
    E --> F{Success?}
    F -->|Yes| G[Display Outputs]
    F -->|No| H[Show Errors]
    G --> I[End]
    H --> I
```

### Time Estimates

| Phase | Duration | Description |
|-------|----------|-------------|
| Template validation | ~30 seconds | Syntax and parameter check |
| VPC + Networking | 1-2 minutes | VPC, subnets, IGW, NAT |
| Security Groups | ~30 seconds | ALB and EC2 security groups |
| ALB + Target Group | 2-3 minutes | Load balancer and listeners |
| Launch Template + ASG | 2-3 minutes | EC2 instances with user data |
| DynamoDB | ~30 seconds | Table creation |
| Health checks | 2-3 minutes | ALB target registration |
| **Total** | **10-15 minutes** | Full deployment |

---

## Terraform Deployment Guide

This section provides a step-by-step tutorial for deploying the same infrastructure using Terraform instead of CloudFormation. Both tools create identical resources.

### Prerequisites

1. Install Terraform (v1.0+):
```bash
# Linux/WSL
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Verify installation
terraform --version
```

2. Configure AWS credentials (same as CloudFormation):
```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_SESSION_TOKEN="your_session_token"  # For lab environments
export AWS_REGION="us-west-2"
```

### Terraform File Structure

```
terraform/
├── main.tf           # All resource definitions
├── variables.tf      # Input variable declarations
├── outputs.tf        # Output value definitions
└── user_data.sh      # EC2 bootstrap script template
```

| File | Purpose |
|------|---------|
| `main.tf` | Defines all AWS resources: VPC, subnets, ALB, ASG, DynamoDB, CloudWatch |
| `variables.tf` | Declares input variables with types, defaults, and descriptions |
| `outputs.tf` | Exposes ALB DNS, VPC ID, and other values after deployment |
| `user_data.sh` | Shell script template rendered with `templatefile()` for EC2 instances |

### Step 1: Initialize Terraform

```bash
cd terraform/

# Download provider plugins and initialize backend
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Installing hashicorp/aws v5.x.x...

Terraform has been successfully initialized!
```

### Step 2: Review the Plan

```bash
# Preview changes without applying
terraform plan
```

This shows all resources that will be created:
```
Plan: 26 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + alb_dns_name = (known after apply)
  + vpc_id       = (known after apply)
```

### Step 3: Apply Configuration

```bash
# Create all resources (type 'yes' when prompted)
terraform apply
```

Or skip confirmation:
```bash
terraform apply -auto-approve
```

### Step 4: Verify Deployment

```bash
# Show outputs
terraform output

# Test the ALB
curl -s "$(terraform output -raw alb_dns_name)/health.html"
```

### Step 5: Destroy Infrastructure

```bash
# Remove all resources
terraform destroy
```

### Customizing Variables

Create a `terraform.tfvars` file (gitignored) to override defaults:

```hcl
# terraform/terraform.tfvars
aws_region       = "us-east-1"
environment      = "prod"
resource_prefix  = "myapp-prod"
instance_type    = "t3.micro"
desired_capacity = 3
```

Or pass variables via command line:
```bash
terraform apply -var="environment=prod" -var="desired_capacity=3"
```

### CloudFormation vs Terraform Comparison

| Aspect | CloudFormation | Terraform |
|--------|----------------|-----------|
| **Syntax** | YAML/JSON | HCL (HashiCorp Configuration Language) |
| **State Management** | Managed by AWS | Local file or remote backend |
| **Drift Detection** | Built-in | `terraform plan` shows drift |
| **Multi-Cloud** | AWS only | AWS, Azure, GCP, and more |
| **Rollback** | Automatic on failure | Manual (destroy and reapply) |
| **Learning Curve** | AWS-specific concepts | Universal IaC patterns |

### Key Terraform Concepts Used

| Concept | Example in This Project |
|---------|-------------------------|
| **Data Sources** | `data.aws_ami.amazon_linux_2` finds latest AMI dynamically |
| **Resources** | `aws_vpc.haweb`, `aws_lb.alb` define infrastructure |
| **Variables** | `var.instance_type` allows customization |
| **Outputs** | `output.alb_dns_name` exposes the ALB endpoint |
| **templatefile()** | Renders `user_data.sh` with variable substitution |
| **Conditional Creation** | `count = var.create_ddb_endpoint ? 1 : 0` |
| **Tags** | All resources tagged for cost allocation and identification |

---

## Verification and Evidence

### Health Verification

The `verify.sh` script performs:

1. **Stack Status Check**: Confirms CREATE_COMPLETE state
2. **ALB DNS Resolution**: Retrieves load balancer endpoint
3. **HTTP Health Check**: Tests /health.html endpoint with retries

### Evidence Collection

The `evidence.sh` script captures:

| Evidence Type | File | Description |
|---------------|------|-------------|
| Stack info | `logs/evidence/stack-info-*.json` | CloudFormation describe-stacks |
| Stack resources | `logs/evidence/stack-resources-*.json` | All stack resources |
| Stack events | `logs/evidence/stack-events-*.json` | Deployment timeline |
| ALB health | `logs/evidence/alb-health-*.txt` | HTTP response test |
| DynamoDB test | `logs/evidence/ddb-test-*.json` | Put/get item verification |

---

## Screenshots

### Project Structure

![Project Structure](docs/screenshots/01-project-structure.png)

### AWS CloudFormation & Compute

![CloudFormation Stack](docs/screenshots/02-aws-cloudformation.png)

![EC2 Instances](docs/screenshots/03-aws-ec2-instances.png)

![Application Load Balancer](docs/screenshots/04-aws-alb.png)

![Auto Scaling Group](docs/screenshots/05-aws-asg.png)

![Target Group Health](docs/screenshots/14-aws-target-group.png)

### Database & Monitoring

![DynamoDB Table](docs/screenshots/06-aws-dynamodb.png)

![DynamoDB Items](docs/screenshots/15-aws-dynamodb-items.png)

![CloudWatch Alarm](docs/screenshots/16-aws-cloudwatch-alarm.png)

### Networking

![VPC](docs/screenshots/08-aws-vpc.png)

![Subnets](docs/screenshots/09-aws-subnets.png)

![Route Tables](docs/screenshots/10-aws-route-tables.png)

![Internet Gateway](docs/screenshots/11-aws-igw.png)

![NAT Gateway](docs/screenshots/12-aws-nat.png)

### Security

![Security Groups](docs/screenshots/13-aws-security-groups.png)

### Web Application

The ALB DNS name is generated dynamically by AWS and displayed after deployment:

```
[OK] Stack deployment completed.
ALB DNS: ha-web-HaWeb-KmrDxwHWSml1-855691521.us-west-2.elb.amazonaws.com
```

**How to access the application:**

1. Copy the ALB DNS from the deployment output
2. Open your browser and navigate to: `http://YOUR-ALB-DNS-NAME/`
3. The web page displays:

| Section | Information Shown |
|---------|-------------------|
| Instance Metadata | Current EC2 instance ID, Availability Zone, private IP, instance type |
| DynamoDB Integration | Table name, AWS region, connection status |
| Registered Instances | All EC2 instances that have registered themselves in DynamoDB |
| Architecture Summary | Load balancing explanation and auto refresh status |

4. Refresh the page multiple times to observe load balancing (different instance IDs)

![Web App Running](docs/screenshots/07-webapp-running.png)

![Load Balanced Response](docs/screenshots/17-webapp-loadbalanced.png)

The DynamoDB Items screenshot shows the instance registration data that appears on the web page:

![DynamoDB Items Detail](docs/screenshots/15-aws-dynamodb-items.png)

### Terminal Operations

![Verify Script](docs/screenshots/18-terminal-verify.png)

![Destroy Process](docs/screenshots/19-terminal-destroy.png)

![Deploy Process](docs/screenshots/20-terminal-deploy.png)

---

## Security

### Network Security

- **No SSH Access**: EC2 instances have no SSH port open
- **Private Subnets**: Application tier isolated from internet
- **NAT Egress**: Outbound-only internet access for updates
- **ALB Only**: Inbound traffic restricted to load balancer

### Data Security

- **DynamoDB Encryption**: Server-side encryption enabled
- **VPC Endpoint**: Optional private access (no internet transit)
- **Credentials**: Never committed to repository (.gitignore)

### Tagging Strategy

All resources are tagged with:

| Tag | Example | Purpose |
|-----|---------|---------|
| `Name` | ha-web-platform-vpc | Resource identification |
| `Project` | ha-web-platform | Cost allocation |
| `Environment` | dev | Environment separation |
| `Description` | Core VPC for HA Web Platform | Functional description |
| `Tier` | Network / Compute / Database | Architecture layer |

---

## AWS Cloud Practitioner Domains


This project demonstrates all four AWS Cloud Practitioner certification domains with real, working implementations. Each concept is not just theoretical—you can see it in action.

---

## Why This Architecture? (Reflection & Learnings)

### How the Project Aligns with AWS Domains

**1. Cloud Concepts**
  - Multi-AZ, ALB, and Auto Scaling ensure high availability and fault tolerance, as recommended by AWS Well-Architected Framework.
  - Infrastructure as Code (CloudFormation & Terraform) enables repeatability, versioning, and rapid recovery.

**2. Security & Compliance**
  - Private subnets, no public SSH, and least-privilege IAM roles by default.
  - VPC Endpoints and encryption at rest for DynamoDB demonstrate advanced security patterns.

**3. Technology**
  - Modular, layered architecture: network, compute, data, monitoring.
  - Automation scripts for deploy/verify/evidence/destroy reflect real DevOps pipelines.

**4. Billing & Pricing**
  - Free tier resources, on-demand billing, and tagging for cost control.
  - Automated destroy scripts prevent orphaned resources and unexpected charges.

### Why These Choices Are Smart

- **Lab-Ready:** Adapted for AWS Academy environments with restricted IAM, using LabInstanceProfile instead of custom roles.
- **Auditability:** Evidence scripts and screenshots provide traceability, supporting compliance and learning.
- **Multi-IaC:** Both CloudFormation and Terraform are included, showing flexibility and multi-cloud readiness.
- **Documentation:** Bilingual, step-by-step, with diagrams and lessons learned—making it accessible and reusable.

### Key Learnings
-
### Future Improvements

- Expand troubleshooting section with more common errors and solutions
- Add more Terraform output examples
- Include a visual comparison table between CloudFormation and Terraform
- Explore CI/CD integration for automated deployments
- Consider adding a Frequently Asked Questions (FAQ) section in both languages

- Real-world constraints (lab permissions, cost optimization) drive creative, robust solutions.
- Automation and evidence are as important as the infrastructure itself for DevOps maturity.
- Clear documentation and reproducibility are essential for onboarding, audits, and knowledge transfer.

---

### Domain 1: Cloud Concepts (24% of exam)

| Concept | Where to See It | What It Demonstrates |
|---------|-----------------|----------------------|
| **High Availability** | Multi-AZ deployment | EC2 instances span `us-west-2a` and `us-west-2b`. If one AZ fails, the other continues serving traffic |
| **Scalability** | Auto Scaling Group | `MinSize: 2, MaxSize: 2, DesiredCapacity: 2` — easily adjustable via parameters |
| **Elasticity** | ASG + CloudWatch | CPU alarm at 80% can trigger scale-out actions (configured for notification) |
| **Fault Tolerance** | ALB Health Checks | Unhealthy instances automatically removed from rotation within 30 seconds |
| **Global Infrastructure** | Region deployment | Template deploys to `us-west-2` (Oregon) but works in any region with AMI adjustment |
| **Shared Responsibility** | LabInstanceProfile | AWS manages EC2 hardware; we manage OS, application, and security groups |

**Evidence command:**
```bash
bash scripts/verify.sh --yes  # Shows 2/2 healthy targets in different AZs
```

### Domain 2: Security & Compliance (30% of exam)

| Concept | Where to See It | What It Demonstrates |
|---------|-----------------|----------------------|
| **Defense in Depth** | Network architecture | 4 layers: Internet → ALB (public) → EC2 (private) → DynamoDB (endpoint) |
| **Least Privilege** | Security groups | ALB SG allows HTTP:80 from 0.0.0.0/0; EC2 SG allows only from ALB SG |
| **Encryption at Rest** | DynamoDB table | `SSESpecification.SSEEnabled: true` with AWS managed keys |
| **Network Isolation** | Private subnets | EC2 instances have no public IPs; outbound via NAT Gateway only |
| **IAM Best Practices** | LabInstanceProfile | Pre-existing role with scoped permissions for DynamoDB access |
| **VPC Endpoint** | Optional endpoint | Private DynamoDB access without traversing internet |

**Security architecture:**
```
Internet → ALB Security Group (port 80) → EC2 Security Group → Private Subnet
                                                                    ↓
                                          VPC Endpoint (optional) → DynamoDB
```

**Evidence command:**
```bash
bash scripts/evidence.sh --yes  # Shows security groups and network configuration
```

### Domain 3: Technology & Services (34% of exam)

| Category | Services | Implementation Details |
|----------|----------|------------------------|
| **Compute** | EC2, ASG, Launch Template | Amazon Linux 2, Python HTTP server, UserData bootstrap |
| **Networking** | VPC, Subnets (4), IGW, NAT, Route Tables, ALB | Custom VPC with CIDR `10.0.0.0/16`, public/private tier separation |
| **Database** | DynamoDB | On-demand table with partition key `id`, instances self-register |
| **Management** | CloudFormation | Single template creates 27 resources with proper dependency ordering |
| **Monitoring** | CloudWatch | CPU utilization alarm at 80% threshold |
| **IaC Alternative** | Terraform | Complete parallel implementation for multi-cloud learning |

**Resource count by category:**
```
Networking:  13 resources (VPC, Subnets, Routes, NAT, IGW)
Compute:      6 resources (ASG, Launch Template, ALB, Listener, Target Group)
Security:     2 resources (ALB SG, EC2 SG)
Database:     2 resources (DynamoDB Table, VPC Endpoint)
Monitoring:   1 resource  (CloudWatch Alarm)
───────────────────────────────────────────────────────────────
Total:       27 resources created by CloudFormation
```

### Domain 4: Billing & Pricing (12% of exam)

| Practice | Implementation | Cost Impact |
|----------|----------------|-------------|
| **Free Tier Usage** | `t2.micro` instances | 750 hours/month free (first 12 months) |
| **On-Demand Pricing** | DynamoDB PAY_PER_REQUEST | No upfront capacity provisioning; pay only for what you use |
| **Resource Tagging** | `Environment` and `Name` tags | Enables Cost Explorer filtering and allocation reports |
| **Cost Control** | `destroy.sh` script | One command to delete all 27 resources—no orphaned resources |
| **Cost Visibility** | All operations logged | Audit trail for cost review and optimization |
| **Single NAT** | One NAT Gateway | ~$45/month savings vs NAT per AZ (acceptable for dev/lab) |

**Cost estimation (lab environment):**
```
Component                Monthly Cost (On-Demand)
─────────────────────────────────────────────────
EC2 t2.micro × 2         $0.00 (Free Tier) or ~$18
NAT Gateway              ~$32 (hourly + data transfer)
ALB                      ~$22 (hourly + LCU)
DynamoDB                 ~$0.25 (minimal usage)
─────────────────────────────────────────────────
Estimated Total          ~$55/month (or ~$35 with Free Tier)
```

**Cleanup command:**
```bash
bash scripts/destroy.sh --yes  # Deletes everything, shows timer: "Stack deleted in 7m 17s"
```

---

## Script Output Examples

The automation scripts provide clear, visual feedback for all operations. Here are examples of actual output:

### Deploy Output

```
============================================================
  CLOUDFORMATION DEPLOYMENT
============================================================

--- Configuration ---
  Template:                iac/main.yaml
  Stack Name:              ha-web-platform
  Region:                  us-west-2

--- Deployment Progress ---
[2025-12-30 05:28:42] [INFO] Initiating stack create/update...

[2025-12-30 05:32:23] [OK]   Deployment completed in 3m 41s
  Final Status:            CREATE_COMPLETE

--- Stack Outputs ---
  ALB DNS:                 ha-web-HaWeb-xxx.us-west-2.elb.amazonaws.com
  VPC ID:                  vpc-0363aa62c8547f081
  Resources Created:       27
```

### Verify Output

```
============================================================
  STEP 2: TARGET GROUP HEALTH
============================================================

--- Target Health Status ---
  TARGET ID              PORT       HEALTH          REASON
  ------------------------------------------------------------
  i-0185c314c73209863    80         healthy         -
  i-0496497f8d65a8632    80         healthy         -

[OK] All targets healthy: 2/2
```

### Evidence Output

```
============================================================
  STEP 4: DYNAMODB EVIDENCE
============================================================

--- Write/Read Test ---
  Test Item ID:            evidence-1767071113
  Write:                   SUCCESS
  Read:                    SUCCESS

--- Registered EC2 Instances ---
  INSTANCE ID            AZ              PRIVATE IP       LAUNCH TIME
  ----------------------------------------------------------------------
  i-0496497f8d65a8632    us-west-2a      10.0.11.90       2025-12-30T04:51:02Z
  i-0185c314c73209863    us-west-2b      10.0.12.202      2025-12-30T04:53:16Z
```

### Destroy Output

```
============================================================
  DELETING INFRASTRUCTURE
============================================================

--- Deletion Progress ---
  [00:00 / 15:00] DELETE_IN_PROGRESS
    > HaWebAlbListener                    DELETE_IN_PROGRESS
    > HaWebCpuAlarmHigh                   DELETE_IN_PROGRESS
  [05:15 / 15:00] DELETE_IN_PROGRESS

[OK] Stack deleted successfully in 7m 17s

============================================================
  DELETION COMPLETE
============================================================
  Stack:                   ha-web-platform
  Status:                  DELETED
```

---

## Troubleshooting

### Common Issues

**Stack in ROLLBACK_COMPLETE state:**
```bash
bash scripts/cleanup.sh --stack-name ha-web-platform --force
bash scripts/fresh-start.sh --force
```

**VPC Endpoint creation fails (AccessDenied):**
```bash
# Edit .env.aws-lab
CREATE_DDB_VPC_ENDPOINT=no

# Redeploy
bash scripts/fresh-start.sh --force
```

**ALB not responding:**
```bash
# Check stack status
bash scripts/verify.sh

# View recent events
aws cloudformation describe-stack-events \
  --stack-name ha-web-platform \
  --region us-west-2 \
  --query 'StackEvents[:10]'
```

### Log Locations

| Log Type | Path |
|----------|------|
| Deployment | `logs/deploy/` |
| Destruction | `logs/destroy/` |
| Verification | `logs/verify/` |
| Evidence | `logs/evidence/` |
| Fresh start | `logs/fresh-start-*.log` |

---

## Downloads

### CloudFormation Template

- [iac/main.yaml](iac/main.yaml) - Complete CloudFormation template

### Terraform Templates

- [terraform/main.tf](terraform/main.tf) - Main configuration
- [terraform/variables.tf](terraform/variables.tf) - Input variables
- [terraform/outputs.tf](terraform/outputs.tf) - Output definitions
- [terraform/user_data.sh](terraform/user_data.sh) - EC2 bootstrap script

### Scripts

- [scripts/fresh-start.sh](scripts/fresh-start.sh) - Full deployment
- [scripts/deploy.sh](scripts/deploy.sh) - CloudFormation deploy
- [scripts/verify.sh](scripts/verify.sh) - Health verification
- [scripts/evidence.sh](scripts/evidence.sh) - Evidence collection
- [scripts/destroy.sh](scripts/destroy.sh) - Stack deletion

---

## Lessons Learned

### What We Built

This project implements a complete high availability web platform that demonstrates real-world cloud architecture patterns:

1. **Network Layer**: Custom VPC with public and private subnets across two Availability Zones, providing network isolation and fault tolerance.

2. **Compute Layer**: Auto Scaling Group with EC2 instances running a Python web application, automatically distributed across AZs.

3. **Load Balancing**: Application Load Balancer distributing HTTP traffic with health checks ensuring only healthy instances receive traffic.

4. **Data Layer**: DynamoDB table where EC2 instances register themselves on boot, demonstrating database integration and instance awareness.

5. **Monitoring**: CloudWatch alarm for CPU utilization, ready to trigger scaling actions or notifications.

6. **Security**: Defense in depth with security groups allowing only necessary traffic (HTTP from ALB to EC2, outbound for updates).

### Technical Approach

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| IaC Tool | CloudFormation primary, Terraform alternative | CloudFormation native to AWS, Terraform for multi-cloud portability |
| Instance Profile | LabInstanceProfile (pre-existing) | AWS Academy labs restrict IAM role creation |
| NAT Gateway | Single NAT in AZ1 | Cost optimization for lab environment (production would use NAT per AZ) |
| DynamoDB | On-demand capacity | No capacity planning needed, pay-per-request pricing |
| VPC Endpoint | Optional via parameter | Some lab roles restrict endpoint creation |

### Key Learnings

1. **Lab Environment Constraints**: AWS Academy labs have restricted IAM permissions. We adapted by using pre-existing LabInstanceProfile instead of creating custom IAM roles.

2. **Resource Naming Consistency**: Using a resource prefix pattern (e.g., `infra-ha-web-dev`) across all resources simplifies identification and cleanup.

3. **CloudFormation Deletion Order**: NAT Gateways must be deleted before Elastic IPs. CloudFormation handles this automatically but takes time.

4. **UserData Debugging**: EC2 UserData logs to `/var/log/cloud-init-output.log`. Essential for troubleshooting bootstrap issues.

5. **AMI Region Dependency**: AMI IDs are region-specific. The same Amazon Linux 2 image has different IDs in us-east-1 vs us-west-2.

### Potential Improvements

| Area | Current State | Improvement |
|------|---------------|-------------|
| HTTPS | HTTP only | Add ACM certificate and HTTPS listener |
| DNS | ALB DNS name | Add Route53 hosted zone with friendly domain |
| Scaling | Manual capacity | Add target tracking scaling policies |
| Secrets | Environment variables | Use AWS Secrets Manager for sensitive data |
| CI/CD | Manual deployment | Add GitHub Actions pipeline for automated deployments |
| Multi-NAT | Single NAT Gateway | Add NAT per AZ for true high availability |
| Backup | No backup | Enable DynamoDB point-in-time recovery |

---

---

## Repository Conventions

### File Organization

This repository follows standard conventions for maintainability:

| Convention | Purpose |
|------------|---------|
| `scripts/lib/` | Shared library functions sourced by all scripts |
| `logs/` | All logs organized by operation type (deploy, verify, destroy) |
| `docs/screenshots/` | Evidence screenshots for documentation |
| `iac/` | CloudFormation templates (primary IaC) |
| `terraform/` | Terraform configuration (alternative IaC) |

### The .gitkeep Convention

Git does not track empty directories. The `.gitkeep` files are placeholder files used to preserve directory structure in version control:

```
logs/
├── .gitkeep           # Preserves logs/ directory
├── deploy/
│   └── .gitkeep       # Preserves deploy/ subdirectory
├── destroy/
│   └── .gitkeep       # Preserves destroy/ subdirectory
├── evidence/
│   └── .gitkeep       # Preserves evidence/ subdirectory
└── menu/
    └── .gitkeep       # Preserves menu/ subdirectory
```

Why this matters:
- Scripts expect these directories to exist for log output
- New users cloning the repository get the correct structure
- The actual log files are gitignored (sensitive/ephemeral data)
- `.gitkeep` is a community convention, not a Git feature

### Files in .gitignore

| Pattern | Reason |
|---------|--------|
| `.env.aws-lab` | Contains AWS credentials |
| `logs/` | Ephemeral deployment logs |
| `*.tfstate*` | Terraform state contains sensitive data |
| `*.tfvars` | May contain secrets (except `.tfvars.example`) |
| `.terraform/` | Downloaded provider plugins |
| `__pycache__/` | Python bytecode |

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Author

Created by [SvillarroelZ](https://github.com/SvillarroelZ)

This project demonstrates production-grade AWS infrastructure patterns for educational purposes and portfolio demonstration.

