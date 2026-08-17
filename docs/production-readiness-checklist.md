# Production readiness checklist

## Architecture and ownership

- [ ] Named service owner, operations owner, security contact, and cost owner.
- [ ] Architecture diagram and ADRs reviewed by someone other than the author.
- [ ] Dependencies, quotas, failure modes, data classification, RTO, and RPO documented.
- [ ] Production is isolated in its own AWS account and state.

## Security

- [ ] IAM Identity Center/MFA for humans; no long-lived CI access keys.
- [ ] GitHub environments protected and workflow/IaC paths covered by CODEOWNERS.
- [ ] TLS certificate and DNS validated; WAF reviewed in count mode before blocking changes.
- [ ] Runtime database user is least privilege; secret rotation is tested.
- [ ] ECR findings reviewed; image signature/SBOM retained; high/critical findings gated.
- [ ] GuardDuty, Security Hub, Config, CloudTrail, Access Analyzer, and central logging enabled at account/platform scope.

## Reliability and operations

- [ ] Two or more healthy tasks distributed across AZs.
- [ ] Deployment failure and rollback tested with a deliberately bad image.
- [ ] Database failover and point-in-time restore tested; measured results meet objectives.
- [ ] Alarm email/on-call target confirmed and every page has a runbook.
- [ ] Dashboard, log queries, request correlation, and ECS Exec audited-access path verified.
- [ ] Capacity limits and service quotas leave failover headroom.

## Delivery

- [ ] CI test, dependency audit, container build, Terraform formatting, and validation pass.
- [ ] Plan reviewed for replacements and sensitive changes; protected approval required for apply.
- [ ] Immutable digest promoted from development; migration is backward compatible.
- [ ] Rollback owner, command, and last known good revision recorded before release.
- [ ] Drift check is clean after deployment.

## Cost and lifecycle

- [ ] Project cost-allocation tag activated.
- [ ] Budget and anomaly notifications delivered to a monitored address.
- [ ] Regional pricing estimate reviewed and major assumptions recorded.
- [ ] Log, backup, snapshot, and image retention match policy.
- [ ] Teardown procedure tested in non-production.

