# Runbook: failed ECS deployment

**Trigger:** `SERVICE_DEPLOYMENT_FAILED` event, unhealthy-target alarm during release, or GitHub deployment timeout.

## Immediate actions

1. Acknowledge the alert and freeze concurrent deployments.
2. Confirm user impact from ALB 5xx, target health, and the service SLO—not from CI status alone.
3. Inspect service deployments/events and stopped-task reasons:

```bash
aws ecs describe-services --cluster CLUSTER --services cloudops-api
aws ecs list-tasks --cluster CLUSTER --service-name cloudops-api --desired-status STOPPED
aws ecs describe-tasks --cluster CLUSTER --tasks TASK_ARN
```

4. Confirm whether the circuit breaker rolled back to the last completed revision. If healthy capacity is falling and rollback is not progressing, update the service to the recorded previous task definition.
5. Do not rerun a failed migration blindly. Determine whether it committed; migrations use a transaction and advisory lock, but an operator must verify `schema_migrations`.

## Diagnosis

- `CannotPullContainerError`: image digest/platform, ECR policy, route/endpoints, or execution role.
- `ResourceInitializationError`: Logs/Secrets Manager reachability, KMS decrypt, or secret ARN.
- Container exits: inspect CloudWatch application logs and task exit code.
- Container runs but target is unhealthy: verify port, liveness path, SG direction, and ALB reason code.
- Readiness fails after healthy deployment: diagnose RDS DNS, SG, TLS certificate, credentials, pool exhaustion, or database capacity.

## Recovery and closure

Smoke test create/list behavior, confirm alarms return to OK, record failed/good task-definition ARNs, then create an incident review with timeline, detection gap, contributing causes, and owned follow-ups.

