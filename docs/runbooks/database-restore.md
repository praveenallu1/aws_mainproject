# Runbook: PostgreSQL point-in-time restore

**Use for:** logical corruption, accidental deletion, or a recovery exercise. Multi-AZ failover does not recover logically corrupted data.

1. Declare an incident, stop destructive writers if appropriate, and record the suspected corruption time in UTC.
2. Confirm the earliest/latest restorable times:

```bash
aws rds describe-db-instances \
  --db-instance-identifier SOURCE_ID \
  --query 'DBInstances[0].[EarliestRestorableTime,LatestRestorableTime]'
```

3. Restore to a **new** identifier and a timestamp safely before corruption. Use the same subnet group, parameter group, KMS key, and database SG.
4. Wait for availability, retrieve a temporary/admin credential securely, and validate schema version, representative row counts, constraints, and application smoke tests.
5. Choose a cutover method: update the application endpoint through reviewed Terraform/configuration, or perform a controlled data merge when transactions after the restore point must be retained.
6. Monitor errors, latency, and data checks after cutover. Preserve the original instance until the retention decision is approved.
7. Record actual RPO/RTO and destroy the test restore after evidence is captured.

Never print secrets into shell history, CI logs, tickets, or screenshots.

