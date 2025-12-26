# Guide: Migrating to Terraform

This guide explains how to migrate the current CloudFormation-based solution to Terraform, step by step. This is for learning and evidence purposes only.

## Steps
1. Install Terraform (`brew install terraform` or from https://www.terraform.io/downloads.html)
2. Initialize a new Terraform project in a `terraform/` folder
3. Create `main.tf`, `variables.tf`, and `outputs.tf` files
4. Map each CloudFormation resource to its Terraform equivalent (see AWS provider docs)
5. Use variables for VPC CIDR, subnets, instance type, etc.
6. Use `terraform plan` to preview changes
7. Use `terraform apply` to deploy
8. Use `terraform destroy` to clean up

## Evidence Checklist
- Screenshot of `terraform plan` output
- Screenshot of `terraform apply` output
- Screenshot of AWS Console showing resources created by Terraform
- Screenshot of `terraform destroy` output

## Notes
- Never commit `.tfstate` files or real credentials
- Use `.env` or environment variables for sensitive data
- Document all variables and outputs
