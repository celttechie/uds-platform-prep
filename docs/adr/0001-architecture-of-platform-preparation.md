# ADR 0001: Architecture of Platform Preparation and Decoupled Cluster Targets

## Status
Accepted

## Context
Deploying software via Defense Unicorns UDS in air-gapped environments requires a functional Kubernetes cluster equipped with the UDS/Zarf toolchain and an in-cluster Zarf registry (`zarf init`).

Previously, infrastructure provisioning (VMs), cluster provisioning (Kubernetes), and software delivery (UDS bundles) were at risk of being conflated into a single monolithic codebase.

## Decision
We establish **`uds-platform-prep`** as a dedicated intermediate layer in a 3-repository ecosystem:
1. **`airgapped-sandbox-vm`**: Foundational virtualization (KVM/Libvirt/OpenTofu on bare metal).
2. **`uds-platform-prep`**: Platform preparation (CLI toolchains, K8s engine [K3s/RKE2/Talos], and Zarf cluster initialization).
3. **`uds-bundle-dev-test`**: Application & Compliance delivery (UDS bundle authoring, packaging, and Lula OSCAL validation).

## Consequences

### Positive
- **Target Agnostic**: Allows preparing single-node sandbox environments (K3s), hardened DoD environments (RKE2), or immutable platforms (Talos) using the exact same operator interface.
- **Repeatable & Automated**: Takes a raw VM or bare-metal host and leaves it 100% prepared to receive any UDS bundle.
- **Independent Upgrades**: Cluster distribution, CNI/CSI, or tool versions can be updated without rebuilding application bundles.
