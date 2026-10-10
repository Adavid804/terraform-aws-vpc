# Agent Instructions for terraform-aws-vpc

## Repository Structure
- `main.tf`: Core VPC resources, route tables, gateways, flow logs.
- `variables.tf`: Input variables.
- `outputs.tf`: Module outputs.
- `versions.tf`: Terraform and provider version constraints.
- `scripts/`: Directory containing executable scripts for format, validation, test, linting, scanning, and docs generation.
- `tests/`: Directory containing `.tftest.hcl` files.

## Conventions
- Follow Terraform best practices.
- Use `terraform fmt` to format code.
- Ensure all resources and modules accept `mandatory_tags`.
- Implement well-architected principles.

## FinOps Guidelines
- Use variables like `single_nat_gateway` to enable shared NAT Gateways across private subnets for non-production environments to reduce cost.
- Apply `mandatory_tags` to all resources for cost attribution.
- Configure retention periods on CloudWatch log groups to avoid infinite retention.

## Commands
When modifying this repository, ensure you run the provided scripts to validate your changes:
- `./scripts/fmt.sh`
- `./scripts/validate.sh`
- `./scripts/lint.sh`
- `./scripts/test.sh`
- `./scripts/scan.sh`
- `./scripts/docs.sh`
