# Threat model

## Assets

- Customer task records in PostgreSQL.
- Database credentials in Secrets Manager.
- Terraform state, which contains infrastructure identifiers and may contain sensitive values.
- GitHub deployment identity and workflow definitions.
- Application images and their software supply chain.
- Operational logs, which may include request metadata.

## Trust boundaries and primary threats

| Boundary | Threat | Implemented control | Residual risk / next control |
|---|---|---|---|
| Internet → ALB | Scanning, injection, request floods | TLS support, WAF managed rules, IP reputation, per-IP rate limit, invalid-header dropping | Tune WAF from sampled requests; add Shield Advanced only when justified |
| ALB → task | Direct task access or lateral movement | Private subnets, no public IP, task SG accepts only ALB SG | Egress still permits TLS to the internet; add an egress proxy/domain controls for high-assurance workloads |
| Task → RDS | Credential theft or unauthorized database access | SG path only from task SG, TLS forced, secret injection, encrypted storage | Master credential is used by the sample; production should create a least-privilege application user or use IAM DB auth/RDS Proxy |
| GitHub → AWS | Stolen workflow token or repository compromise | OIDC temporary credentials, exact repository/environment subject, protected production environment, scoped app-deploy policy | Pin actions to commit SHAs and require CODEOWNERS for workflow/IaC paths |
| Image → runtime | Vulnerable or malicious dependency | Lock file, npm audit, ECR scan-on-push, non-root user, read-only root filesystem, dropped Linux capabilities | Add signed images and admission verification; gate on enhanced Inspector findings |
| Operator → AWS | Excess privilege or unaudited emergency change | Federated identity, MFA expectation, CloudTrail platform baseline, IaC workflow | Add break-glass procedure, SCPs, permission boundaries, and periodic access review |
| State backend | Data disclosure or concurrent corruption | S3 public block, KMS encryption, TLS-only policy, versioning, lockfile | Separate tooling account and tightly scoped backend roles |
| Logs | Secret/PII leakage | Authorization header redaction in WAF logs, retention and restricted buckets | Add application log redaction tests and organization log archive controls |

## Abuse cases to test

1. Send common injection payloads and confirm WAF count/block behavior without breaking valid requests.
2. Attempt to connect to the task or RDS from the internet; no route or security-group path should exist.
3. Alter a GitHub OIDC subject (fork, branch, or environment) and confirm role assumption is denied.
4. Push a vulnerable dependency in a branch and confirm the audit gate fails.
5. Remove secret permission and confirm the deployment fails closed and rolls back.

Review this model after every new public route, data class, third-party API, or CI permission.

