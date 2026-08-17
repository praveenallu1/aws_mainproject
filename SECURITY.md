# Security policy

This repository is a learning project and is not a monitored security product. Do not open a public issue containing credentials, account IDs that must remain private, customer data, Terraform state, or exploitable details from a real deployment.

For a private deployment, report suspected compromise through the account owner's established incident channel. Immediately preserve CloudTrail and workload evidence, revoke or disable the affected trust path, rotate exposed credentials, and follow the organization's incident-response process.

## Supported state

Only the latest `main` branch is maintained. Dependencies and GitHub Actions are checked weekly, but operators remain responsible for reviewing ECR/Inspector findings, AWS service notifications, Terraform provider changes, and base-image updates before deployment.

## Secret handling

- Never commit `.env`, `*.auto.tfvars`, backend configuration, state, plans, credentials, or exported Secrets Manager values.
- Use federated human access and GitHub OIDC; do not create AWS access keys for this project.
- Treat Terraform plan files as sensitive artifacts.
- Redact account identifiers, hostnames, request data, and email addresses from portfolio screenshots.

