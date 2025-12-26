# HA Web Platform with AWS IaC

## Project Overview
This project demonstrates a highly available, secure, and reproducible web platform on AWS using Infrastructure as Code (CloudFormation). It is designed for AWS Cloud Practitioner learning and real-world DevOps skills.

## Architecture Diagram
```mermaid
graph TD
    A[VPC]
    A --> B[Public Subnet 1 (AZ1)]
    A --> C[Public Subnet 2 (AZ2)]
    B & C --> D[Internet Gateway]
    B & C --> E[Route Table]
    E --> D
    B & C --> F[ALB SG]
    F --> G[Application Load Balancer]
    G --> H[Target Group]
    H --> I[EC2 Instance(s) in ASG]
    I --> J[EC2 SG]
    G --> K[CloudWatch Alarm]
```

## Prerequisites
- AWS CLI configured (lab role/profile)
- CloudFormation permissions
- Bash shell

## Deployment Steps
1. Clone this repository
2. Install requirements: `pip install -r requirements.txt`
3. Deploy: `./scripts/deploy.sh`

## Verification Steps
1. Run: `./scripts/verify.sh`
2. Check ALB DNS output and HTTP response

## Security Notes
- No SSH open to the world
- Only HTTP via ALB
- EC2 only accessible from ALB SG
- SSM option explained in docs/architecture.md

## Cost & Cleanup
- Use `./scripts/destroy.sh` to remove all resources
- Resources use free tier where possible

## Troubleshooting
- See CloudFormation Events for errors
- Check IAM permissions (lab restrictions)

## AWS Cloud Practitioner Mapping
- VPC, Subnets, IGW, Route Table: Networking
- ALB, ASG: High Availability & Elasticity
- Security Groups: Secure by default
- CloudWatch: Observability
- IaC: Reproducibility

---

For detailed architecture and evidence, see `/docs/`.
