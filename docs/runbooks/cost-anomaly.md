# Runbook: unexpected AWS cost

1. Confirm whether the alert is actual or forecasted and identify account, Region, service, usage type, and project tag.
2. Compare the start time with deployments, load tests, log changes, backup copies, and data transfer.
3. Look specifically for forgotten NAT gateways, RDS instances/snapshots, interface endpoints, Elastic IPs, high log ingestion, and cross-AZ/internet transfer.
4. Contain only when ownership and impact are understood. Prefer scaling or planned teardown; do not delete unidentified stateful resources.
5. Verify that the cost allocation tag is activated and present. Untagged cost should be assigned an owner.
6. Record the root cause, dollars at risk, containment, prevention control, and whether the budget threshold or forecast needs tuning.

