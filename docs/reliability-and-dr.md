# Reliability and disaster recovery

## Availability design

- The production profile spans three Availability Zones and runs at least two Fargate tasks.
- The ALB distributes traffic only to healthy task IPs.
- Production uses one NAT gateway per AZ, avoiding a single-AZ egress dependency.
- RDS Multi-AZ provides synchronous standby and managed failover; it does not replace backups.
- ECS rolling deployment health checks and the deployment circuit breaker preserve the last completed revision.

## Recovery objectives

| Scenario | RPO | RTO | Strategy |
|---|---:|---:|---|
| Failed application release | 0 | 10 minutes | ECS circuit-breaker rollback or explicit previous task revision |
| Task/AZ failure | 0 | 10 minutes | ECS replacement and ALB health routing |
| Database instance failure | 0 for committed synchronous transactions | 10 minutes target | RDS Multi-AZ failover |
| Logical corruption/deletion | 15 minutes | 60 minutes | Point-in-time restore to a new instance, validate, then switch endpoint |
| Regional outage | 15 minutes target | 4 hours | Rebuild from Terraform in recovery Region and restore copied backup |

Cross-Region automated-backup replication and DNS failover are roadmap controls. Until they are implemented and tested, the regional RPO/RTO are objectives, not guarantees.

## Restore-test acceptance criteria

- Restore never overwrites the source database.
- A timestamp and restore point are recorded in UTC.
- Schema migration version and representative row counts match expectations.
- The application passes readiness and a create/list smoke test.
- Measured RPO and RTO are recorded.
- Temporary restored resources are destroyed after evidence is captured.

Run an in-Region restore quarterly and a regional rebuild at least twice per year in a sandbox.

