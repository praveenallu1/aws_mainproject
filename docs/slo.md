# Service level objectives

## User journey

A user can create and list tasks through the public API. The liveness endpoint is an infrastructure probe and is not counted as a user journey.

## Indicators and objectives

| Indicator | Measurement | Objective |
|---|---|---|
| Availability | Successful non-5xx API responses / valid API requests at the ALB | 99.9% over a rolling 30 days |
| Latency | ALB `TargetResponseTime` for API routes | 95% below 500 ms over a rolling 30 days |
| Freshness | Time from approved deployment to healthy service | 95% below 10 minutes |
| Durability | Successful tested restore within stated RPO | 100% of quarterly restore exercises |

At 99.9% availability, the 30-day error budget is approximately 43.8 minutes. Alerts should page on fast error-budget burn, while slower degradation should create a ticket. Static CPU alone is not a user-impact page.

## Exclusions

Exclude explicitly announced maintenance exercises and rejected invalid requests (4xx). Do not exclude failed deployments, dependency failures, or operator mistakes simply because they are inconvenient; those are exactly the events the SLO is intended to expose.

## Review cadence

Review indicators monthly. When the error budget is exhausted, pause risky feature releases and prioritize reliability work, alarm tuning, and contributing-cause removal.

