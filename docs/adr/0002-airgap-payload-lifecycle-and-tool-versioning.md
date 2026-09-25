# ADR 0002: Air-Gap Payload Lifecycle and Automated Tool Versioning

## Status
Accepted

## Context
Air-gapped systems cannot fetch binary updates or container images dynamically from the internet. Operators must be able to:
1. Track and pin exact versions of platform toolchains (`uds`, `zarf`, `kubectl`, `lula`, `k3s`, `rke2`).
2. Automatically check for new releases and bump versions.
3. Package and push updated toolchains and air-gap packages across network boundaries without manual file hunting.

## Decision

1. **Centralized Version Matrix (`versions.env`)**:
   - All toolchains and runtime package versions are declared in a single source of truth (`versions.env`).
2. **Automated Release Tracking (`scripts/update-versions.sh`)**:
   - Automated scripts query GitHub release APIs to discover newer releases of UDS, Zarf, Lula, and K3s.
3. **Reproducible Payload Ingestion (`scripts/download-payloads.sh`)**:
   - Fetches and stages binaries and `.tar.zst` airgap image archives into `payloads/bin` and `payloads/packages`.
4. **Zero-Touch Remote Deployment (`scripts/deploy-target.sh`)**:
   - Synchronizes payloads over SSH/jump-host, applies cluster runtime configs, and runs `zarf init` in a single command (`make deploy`).

## Consequences

### Positive
- Predictable and auditable toolchains across all test and production environments.
- Fast synchronization to air-gapped target hosts over standard SSH jump connections.
