# Architecture, Troubleshooting, and Migration Guide

## Architecture Rationale

This project provisions a minimal, secure, and cost-controlled HA web platform on AWS, using only the resources strictly necessary for a professional lab/demo. All design decisions are explained for clarity and learning.

- **VPC & Subnets:** Isolated network, two public subnets in different AZs for high availability. No private subnets to keep the lab simple and cost-free.
- **Internet Gateway & Route Table:** Required for outbound internet access (for ALB/EC2 updates, health checks, and evidence collection).
- **Security Groups:**
  - ALB SG: Only allows HTTP (port 80) from anywhere. No SSH, no RDP, no admin ports.
  - EC2 SG: Only allows HTTP from ALB SG. No public access, no SSH, no RDP.
- **ALB:** Public, internet-facing, for HTTP only. No HTTPS for simplicity/cost. No WAF or logging by default (see recommendations).
- **ASG & Launch Template:** Ensures at least 2 instances in 2 AZs for HA. Only free-tier compatible AMI and instance type. No SSH keys, no EBS costs.
- **CloudWatch Alarm:** Demo only, no scaling policy attached (cost control, safe for lab).

## Troubleshooting

### Common Issues & Solutions

- **Stack creation fails:**
  - Check CloudFormation Events in the AWS Console for error details.
  - Validate AWS credentials and region in `.env.aws-lab`.
  - Ensure sufficient AWS service quotas and permissions.
- **ALB DNS not resolving:**
  - Wait for DNS propagation and verify stack outputs.
- **Web page not loading:**
  - Confirm EC2 health in the Target Group and check Security Groups.
- **Stack deletion issues:**
  - Avoid manual changes outside CloudFormation and use the AWS Console to resolve dependencies.
- **Script errors:**
  - Ensure all dependencies are installed (`awscli v2`, `cfn-lint`, `jq`, `curl`).
  - Run scripts with `-h` for help and usage details.

## Lessons Learned

- Security by design: No public SSH, least-privilege, no hardcoded credentials.
- Reproducibility: IaC enables consistent, repeatable environments.
- Validation: Linters and automated scripts catch errors early.
- Cost awareness: Destroy instructions and free-tier usage avoid surprises.
- Documentation: Evidence collection and clear outputs are key for audits and learning.
- Migration flexibility: Design is portable to Terraform.

## Step-by-Step Guide: Migrating to Terraform

1. **Initialize Terraform:**
   ```sh
   cd terraform
   terraform init
   ```
2. **Review/Edit Variables:**
   - Edit `variables.tf` to set region, CIDRs, instance type, AMI, etc.
3. **Plan Changes:**
   ```sh
   terraform plan
   ```
4. **Apply Configuration:**
   ```sh
   terraform apply
   ```
5. **Collect Evidence:**
   - Use `terraform output` and take screenshots of AWS Console resources, outputs, and billing dashboard.
6. **Destroy Resources:**
   ```sh
   terraform destroy
   ```

### What to Screenshot for Evidence
- Terraform outputs (VPC ID, subnet IDs, ALB DNS, ASG name)
- AWS Console: CloudFormation/Terraform resources, EC2, ALB, VPC
- Billing Dashboard (confirm no unexpected charges)
- Web page via ALB DNS

> **Tip:** Never commit `.tfstate`, `.terraform/`, or credentials. Use remote state for production.

---

This guide ensures you can troubleshoot, document, and migrate your lab with confidence and professionalism.