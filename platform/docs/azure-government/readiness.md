# Azure Government readiness translation

This document is a translation aid only. Azure Government is not implemented in
this repository and it is not cloud validated. The AWS-oriented Project A
artifacts can be mapped to sovereign-cloud planning concepts, but no Azure
subscription hierarchy, policy deployment, or landing zone has been created.

## Translation boundaries

- AWS Organizations maps conceptually to management groups and subscriptions.
- SCP and permission-boundary ideas map conceptually to Azure Policy and RBAC.
- Log Archive and audit-path concepts map conceptually to sovereign logging and
  retention controls.

## What remains out of scope

- Azure Government endpoints, subscriptions, and policies remain unbuilt in this repository.
- Sovereign networking, identity, and logging are not cloud validated here.
- No claim should describe Azure Government as deployed or validated because this
  repository stays repo-only and the sovereign work remains not implemented.

See [claims boundary](../portfolio/claims-boundary.md) for the wording that
should be used in reviews and portfolio discussions.
