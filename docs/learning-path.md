# Role-focused learning path

Treat this repository as a twelve-week production ownership simulation. For every phase, keep evidence: a diagram, plan output, dashboard screenshot, incident timeline, cost report, or short design note. That evidence gives you concrete STAR stories in interviews.

## Phase 1 — Architecture and networking

Build and explain the request path from WAF to ALB to Fargate to RDS. Calculate every subnet CIDR manually, identify route-table associations, and explain why the database tier has no default route.

**Exercise:** temporarily break the application route to the NAT gateway, observe task start failures, use VPC Flow Logs and ECS events to diagnose them, then restore the route through Terraform.

**Interview evidence:** explain public, private, and isolated subnets; stateful security groups; Multi-AZ trade-offs; NAT gateway availability and cost.

## Phase 2 — Identity and secrets

Trace the human admin role, GitHub OIDC role, ECS execution role, and ECS task role. Explain why application AWS permissions belong on the task role while image pulls and secret injection use the execution role.

**Exercise:** remove `secretsmanager:GetSecretValue` in a branch, predict the failure, apply only in a sandbox, and find the `ResourceInitializationError` in ECS events.

**Interview evidence:** temporary credentials, trust policy versus permission policy, `iam:PassRole`, environment-scoped OIDC subjects, secrets that never enter Terraform state.

## Phase 3 — Containers and deployments

Build the ARM64 image, inspect its SBOM, push an immutable tag, and deploy a new task-definition revision. Study minimum/maximum healthy percentages and the deployment circuit breaker.

**Exercise:** deploy an image with a failing liveness check. Capture the failed deployment event, automatic rollback, service events, and last known good revision.

**Interview evidence:** immutable artifacts, graceful shutdown, health check design, migration sequencing, rolling versus blue/green deployments.

## Phase 4 — Data and recovery

Run migrations, take a manual snapshot, write sample records, and perform a point-in-time restore into a new instance. Validate row counts and application connectivity without overwriting the source database.

**Exercise:** measure restore time against the stated RTO and record the newest recoverable transaction against the RPO.

**Interview evidence:** Multi-AZ is high availability, not backup; PITR, snapshot retention, restore testing, SSL enforcement, secret rotation implications.

## Phase 5 — Observability and SLOs

Generate traffic, read ALB access logs, query structured application logs, inspect Container Insights, and correlate request IDs. Tune an alarm only after observing normal baselines.

**Exercise:** introduce 500 responses or database latency in a branch, confirm the correct signal fires, follow the runbook, and write a blameless post-incident review.

**Interview evidence:** symptoms versus causes, golden signals, actionable alarms, error budgets, log retention and cost.

## Phase 6 — Infrastructure delivery

Create a feature branch that changes task memory. Let CI validate it, generate a cloud plan with the plan role, review replacement risk, apply through a protected environment, and confirm drift is absent.

**Exercise:** make a console change to a security group, detect it with `terraform plan -refresh-only`, and remediate through code.

**Interview evidence:** remote state locking, provider locking, plan/apply separation, drift, policy gates, targeted apply as a bootstrap exception.

## Phase 7 — Reliability and scaling

Load test the service, observe CPU/memory target tracking, and identify whether the database or application becomes the bottleneck. Stop a task and observe replacement. Trigger an RDS reboot with failover in the sandbox.

**Exercise:** compare one-task development behavior to two-task production behavior during a rolling release.

**Interview evidence:** horizontal scaling, back pressure, connection pools, failure domains, capacity headroom, quota awareness.

## Phase 8 — Cost optimization

Use Cost Explorer and Cost and Usage Reports to separate NAT, Fargate, ALB, RDS, endpoints, logs, and data transfer. Compare the cost and reliability of one NAT gateway versus one per AZ. Right-size using observed metrics.

**Exercise:** decide when interface endpoints save money versus NAT processing, and document the break-even assumptions rather than asserting a universal answer.

**Interview evidence:** cost allocation tags, unit economics, Graviton, Spot suitability, retention policies, architectural cost trade-offs.

## Phase 9 — Security review

Run Trivy/Checkov or equivalent, review IAM Access Analyzer findings, inspect ECR scan results, test WAF sampled requests, and confirm public-access blocks. Create a threat-model update for every new external dependency.

**Interview evidence:** defense in depth, security ownership, vulnerability prioritization, network segmentation, encryption boundaries.

## Phase 10 — Production readiness review

Complete the checklist, perform a game day, restore a backup, test a failed deployment, verify notification delivery, and have another engineer follow a runbook without verbal help.

**Portfolio deliverables:** architecture diagram, ADRs, redacted plan, successful pipeline, CloudWatch dashboard, incident review, restore evidence, monthly cost breakdown, and a two-minute project explanation.

## Suggested interview summary

> I built and operated a multi-AZ ECS platform using Terraform. I separated public, application, and database tiers; used OIDC and workload roles instead of long-lived keys; added immutable deployments with automatic rollback; defined SLOs, alarms, and restore procedures; and tested failure modes and cost trade-offs. Development is deliberately inexpensive, while Terraform checks prevent those compromises from reaching production.

