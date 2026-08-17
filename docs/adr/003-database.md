# ADR 003: RDS PostgreSQL with managed master secret

- **Status:** Accepted with follow-up
- **Decision date:** 2026-08-17

## Context

The sample API needs relational consistency and a realistic stateful recovery exercise. The team should practice backups, Multi-AZ failover, performance monitoring, TLS, migrations, and secret handling without administering database hosts.

## Decision

Use RDS PostgreSQL 16 with gp3 storage, encryption, Performance Insights, Enhanced Monitoring, PostgreSQL log export, automated backups, and an RDS-generated master password in Secrets Manager. Production enables Multi-AZ and deletion protection.

## Consequences

- AWS manages database host patching, backups, and failover mechanics.
- Multi-AZ increases cost but removes a single-instance failure from the production design.
- The sample initially uses the master credential to keep bootstrap understandable. Before real production data, create a least-privilege application role, separate migration role, and tested credential-rotation process. Consider RDS Proxy or IAM database authentication based on measured connection behavior and operational needs.

