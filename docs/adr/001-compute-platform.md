# ADR 001: ECS on Fargate for the initial platform

- **Status:** Accepted
- **Decision date:** 2026-08-17

## Context

The workload is a small stateless HTTP service. The learning goal is production AWS ownership, not Kubernetes cluster administration. The platform needs private networking, workload IAM, autoscaling, immutable deployments, and low host-management overhead.

## Decision

Run the service on Amazon ECS using Fargate and `awsvpc` networking. Use ARM64 tasks, an ALB, capacity-provider strategies, health checks, and a rolling deployment circuit breaker.

## Consequences

- No EC2 host patching, AMI lifecycle, or cluster capacity management.
- Every task receives an ENI/security group boundary and can use a dedicated task role.
- Fargate has a price premium at stable high utilization and less host-level flexibility.
- EKS is not justified by current requirements. Reconsider it if portability, Kubernetes APIs/ecosystem, complex multi-service scheduling, or organizational standards outweigh the operational cost.

