# Runbook: high API latency

**Trigger:** p95 target response time breaches the SLO or fast error-budget burn.

1. Confirm scope: routes, AZs, time window, and whether 5xx or request volume changed.
2. Compare ALB request/latency with ECS CPU, memory, running task count, deployment history, and scaling activity.
3. Inspect application logs by request ID and duration. Check event-loop stalls, downstream timeouts, and pool-wait symptoms.
4. Inspect RDS Performance Insights, connections, CPU, free memory/storage, IOPS/latency, locks, and slow queries.
5. Check NAT/endpoint metrics and VPC Flow Logs only if the request path calls external services.

Safe mitigations include scaling tasks within tested limits, stopping a bad deployment, disabling a costly nonessential feature, or applying a previously rehearsed database capacity change. Do not increase timeouts as a first response; that can amplify queueing and resource exhaustion.

Close only after latency and error-budget burn recover, the mitigation is stable, and a contributing-cause follow-up has an owner.

