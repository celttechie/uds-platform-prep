# UDS Platform Prep (`uds-platform-prep`)

A dedicated automation repository for preparing, toolchaining, and initializing target Kubernetes environments (**K3s**, **RKE2**, **Talos**) for **Defense Unicorns UDS (Unified Delivery System)** and **Zarf** deployments in air-gapped infrastructure.

---

## 3-Repository Ecosystem

```
┌─────────────────────────────────────────────────────────────┐
│ 1. airgapped-sandbox-vm (Virtualization Layer)              │
│ • OpenTofu / Libvirt on Dell T5600                          │
│ • Provisions isolated guest VMs (10.160.0.34)               │
└──────────────────────────────┬──────────────────────────────┘
                               │ Clean VM Ready
┌──────────────────────────────▼──────────────────────────────┐
│ 2. uds-platform-prep (This Repo - Platform Prep Layer)      │
│ • Downloads & updates toolchains (uds, zarf, kubectl, lula) │
│ • Installs selected K8s runtime (K3s / RKE2 / Talos)        │
│ • Runs `zarf init` (in-cluster registry & webhook)          │
└──────────────────────────────┬──────────────────────────────┘
                               │ UDS-Ready Cluster
┌──────────────────────────────▼──────────────────────────────┐
│ 3. uds-bundle-dev-test (Software & Bundle Layer)            │
│ • Packages and deploys UDS bundles across the air-gap       │
└─────────────────────────────────────────────────────────────┘
```

---

## Features

- **Automated Version Tracking**: Query GitHub release endpoints to detect and bump tool versions (`make update-versions`).
- **Air-Gap Asset Ingestion**: Downloads CLI binaries, Zarf init packages, and K8s air-gap images into `payloads/` (`make download`).
- **One-Command Target Prep**: Packages payloads, syncs across SSH jump host (`t5600`), deploys Kubernetes, runs `zarf init`, and retrieves `kubeconfig` (`make deploy`).
- **Multi-Target Support**:
  - `k3s-sandbox`: Lightweight single-node dev/test runtime.
  - `rke2-hardened`: DoD STIG and FIPS 140-2/3 compliant enterprise runtime.
  - `talos-nested`: Immutable OS and API-managed Kubernetes platform.

---

## Quick Start

### 1. Configure Target Connection
```bash
make configure
# Edit target.env with your host details (defaults to 10.160.0.34 via t5600)
```

### 2. Download Toolchains & Air-Gap Assets
```bash
make download
```

### 3. Deploy Runtime & Initialize Zarf on Air-Gapped Target
```bash
make deploy
```

### 4. Check Cluster Status
```bash
make status
```

---

## Updating Toolchains as New Releases Occur

To discover and update to newer releases of `uds`, `zarf`, `kubectl`, `lula`, or `k3s`:

1. **Check & update `versions.env`**:
   ```bash
   make update-versions
   ```
2. **Download new releases**:
   ```bash
   make download
   ```
3. **Push updates to air-gapped target**:
   ```bash
   make deploy
   ```

---

## Directory Structure

```
uds-platform-prep/
├── docs/adr/              # Architecture Decision Records
│   ├── 0001-architecture-of-platform-preparation.md
│   └── 0002-airgap-payload-lifecycle-and-tool-versioning.md
├── payloads/              # Local storage for air-gap assets (git-ignored)
│   ├── bin/               # CLI binaries (uds, zarf, kubectl, lula, k3s)
│   └── packages/          # Zarf init and K8s airgap tar.zst packages
├── scripts/
│   ├── download-payloads.sh # Ingests tools based on versions.env
│   ├── update-versions.sh   # Discovers new releases from GitHub
│   └── deploy-target.sh     # Remote push and cluster initialization
├── targets/               # Environment target definitions
│   ├── k3s-sandbox/
│   ├── rke2-hardened/
│   └── talos-nested/
├── versions.env           # Centralized toolchain version matrix
├── target.env.example     # Target connection template
├── Makefile               # Task automation entrypoint
└── README.md
```
