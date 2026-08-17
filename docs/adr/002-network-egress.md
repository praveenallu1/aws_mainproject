# ADR 002: Three-tier VPC and environment-specific egress

- **Status:** Accepted
- **Decision date:** 2026-08-17

## Context

Only the ALB must accept internet traffic. Tasks need outbound access for image/runtime integrations, while PostgreSQL does not need internet routing. NAT gateways and interface endpoints both have material fixed and data-processing costs.

## Decision

Create public, private application, and isolated database subnets in each AZ. Production uses a NAT gateway per AZ and selected interface endpoints. Development uses one NAT gateway and disables charged interface endpoints by default. A free S3 gateway endpoint is enabled in both.

## Consequences

- Production avoids cross-AZ dependency on a single NAT gateway.
- Development accepts a documented availability compromise to control spend.
- Database subnets have no default route.
- Interface endpoints improve private AWS API access but are not universally cheaper; retain them only after security and traffic economics are reviewed.

