# Well-Architected self-review

## Operational excellence

Strengths: infrastructure and releases are automated; dashboards, alarms, event notifications, runbooks, and ADRs live with the code. Exercises require post-incident evidence.

Gaps: add automatic synthetics, on-call routing, runbook ownership/expiry, and organization-wide change/audit integration.

## Security

Strengths: private task/data tiers, scoped security groups, encryption, RDS-managed secret, OIDC, non-root/read-only containers, WAF, flow logs, and immutable ECR tags.

Gaps: replace the database master user with a least-privilege runtime user, pin GitHub Actions to commit SHAs, add image signing, and implement organization controls such as SCPs, GuardDuty, Security Hub, Config, and centralized CloudTrail.

## Reliability

Strengths: three-AZ production network, redundant tasks, Multi-AZ RDS, autoscaling, health-based routing, automatic deployment rollback, PITR, and tested restore criteria.

Gaps: implement cross-Region backup replication, Route 53 recovery routing, synthetic canaries, and automated quarterly recovery tests.

## Performance efficiency

Strengths: Fargate removes host management, ARM64 improves price/performance, target tracking responds to CPU/memory, and Performance Insights exposes database behavior.

Gaps: baseline under load, tune the database pool, add request-count scaling if it predicts demand better, and test RDS Proxy when connection churn becomes significant.

## Cost optimization

Strengths: cost tags, budget, ARM64, Spot only in development, right-sized profiles, retention controls, and a deliberate NAT/endpoint trade-off.

Gaps: add CUR analysis, anomaly detection, non-production scheduling, and measured unit-cost reporting.

## Sustainability

Strengths: managed/serverless compute, autoscaling, ARM64, bounded retention, and small development capacity reduce idle resources.

Gaps: measure utilization, remove idle environments automatically, and select Regions/resources using business and carbon considerations together.

