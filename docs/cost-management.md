# Cost management

The development profile reduces cost but is not production-equivalent. Price the exact Region and usage with AWS Pricing Calculator before deployment; AWS prices and free-tier terms change.

## Main cost drivers

| Driver | Why it matters | Development choice | Production choice |
|---|---|---|---|
| NAT Gateway | Hourly charge plus processed data | One gateway across two AZs | One per AZ; evaluate endpoints/egress architecture |
| RDS | Instance, storage, backups, I/O | Small single-AZ Graviton instance | Multi-AZ, larger instance, longer retention |
| ALB and WAF | Hourly capacity and requests/rules | Still enabled so behavior is realistic | Same, sized by traffic |
| Fargate | vCPU/memory runtime | One ARM task, optionally Spot | Two+ on-demand ARM tasks with autoscaling |
| Interface endpoints | Hourly per endpoint per AZ plus data | Disabled | Enabled when security/reliability or traffic economics justify them |
| Logs and metrics | Ingestion, storage, queries | 14-day retention | 90-day workload retention plus central archive |

## Guardrails

- Set `alarm_email` and `monthly_budget_usd`; confirm both subscriptions.
- Activate the `Project` cost allocation tag in the Billing console before relying on tag-filtered budgets.
- Review Cost Explorer daily during hands-on exercises.
- Destroy development environments when not in use; verify all NAT gateways and RDS snapshots explicitly.
- Use load-test data to right-size CPU, memory, and database class.
- Treat Fargate Spot as interruptible; it is disabled by the production safety check.
- Use S3 lifecycle rules and explicit CloudWatch retention rather than retaining telemetry forever.

## Cost review questions

1. What is the monthly baseline before the first request?
2. What is the cost per million requests at expected payload sizes?
3. Which resource grew fastest week over week, and why?
4. Is NAT processing or a set of interface endpoints cheaper for the measured traffic pattern?
5. Can a managed service or scheduled non-production shutdown remove operational work or idle cost?

