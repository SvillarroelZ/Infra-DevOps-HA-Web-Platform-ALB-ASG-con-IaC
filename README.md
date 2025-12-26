# HA Web Platform with AWS IaC

## Project Overview
This project demonstrates a highly available, secure, and reproducible web platform on AWS using Infrastructure as Code (CloudFormation). All resources are for lab/testing purposes only and must be destroyed after use to avoid unnecessary costs.

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
- All resources are created for lab/testing only. Do not use in production.
- Copy .env.example to .env and fill in your lab/external connection details if needed (never commit real secrets)

## Deployment Steps
1. Clone this repository
2. Install requirements: `pip install -r requirements.txt`
3. Deploy: `./scripts/deploy.sh`

## Verification Steps
1. Run: `./scripts/verify.sh`
2. Check ALB DNS output and HTTP response
3. Confirm that the web page shows InstanceId and AZ (proves load balancing and multi-AZ)

## Security Notes
- No SSH or RDP is exposed to the internet
- Only HTTP (port 80) is open to the world, and only via the ALB
- EC2 instances only accept HTTP from the ALB Security Group, never from the public
- The IP 169.254.169.254 used in UserData is AWS's metadata service, not a personal or public IP
- All resources are for lab/testing and should be destroyed after use

## Cost & Cleanup
- Use `./scripts/destroy.sh` to remove all resources after testing
- All resources use free tier where possible, but always check your AWS billing dashboard
- Never leave lab resources running after your session

## Troubleshooting
- Check CloudFormation Events for errors (e.g., IAM, subnet, or AZ issues)
- Ensure your AWS CLI is using the correct lab role/profile
- If stack creation fails, run `destroy.sh` and try again
- For metadata errors, confirm that the instance can reach 169.254.169.254 (default in AWS)

## Evidence Collection
- Use `./scripts/evidence.sh` to print all stack outputs and a checklist for screenshots
- Store screenshots in `docs/screenshots/` and describe them in `docs/evidence.md`
- Never commit real credentials or .env files

## Lessons Learned
- Secure-by-default design: no public SSH, only HTTP via ALB
- Modular, parameterized IaC for reproducibility
- Observability with CloudWatch alarms
- Cost awareness: always destroy lab resources
- AWS metadata IP is safe and standard for dynamic instance info

## AWS Cloud Practitioner Mapping
- VPC, Subnets, IGW, Route Table: Networking
- ALB, ASG: High Availability & Elasticity
- Security Groups: Secure by default
- CloudWatch: Observability
- IaC: Reproducibility

## Continuous Integration (CI)
- This repository includes a GitHub Actions workflow to validate CloudFormation templates and shell scripts on every push and pull request.
- See `.github/workflows/validate.yml` for details.

## Testing and Validation
- Manual: Use `verify.sh` and `evidence.sh` scripts to check deployment and collect evidence.
- Automated: CI will lint all YAML and shell scripts.
- For advanced testing, see the `test/` branch (if available).

## Terraform Migration
- See `docs/terraform-migration.md` for a step-by-step guide to migrate this solution to Terraform, including an evidence checklist.

## Evidence Table
| Objective | Evidence (Screenshot/File) |
|-----------|---------------------------|
| VPC/Subnets created | AWS Console, evidence.sh |
| ALB DNS reachable | Browser, evidence.sh |
| ASG scaling events | AWS Console |
| CloudWatch alarm | AWS Console |
| Cleanup | AWS Console, billing dashboard |

## Cost Awareness
- All resources are for lab/testing only. Always destroy resources after use.
- Monitor your AWS billing dashboard to avoid unexpected charges.
- Never leave resources running after your session.

---

For detailed architecture and evidence, see `/docs/`.
