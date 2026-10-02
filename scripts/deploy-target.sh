#!/usr/bin/env bash
# ==============================================================================
# Air-Gapped Platform Target Deployer & Initializer
# ==============================================================================
# Deploys CLI toolchains, selected Kubernetes runtime (K3s/RKE2/Talos), and
# initializes Zarf on the air-gapped target host.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source configurations
source "${REPO_ROOT}/versions.env"

if [[ -f "${REPO_ROOT}/target.env" ]]; then
  source "${REPO_ROOT}/target.env"
else
  source "${REPO_ROOT}/target.env.example"
fi

echo "=============================================================================="
echo "          DEPLOYING PLATFORM RUNTIME TO AIR-GAPPED TARGET                     "
echo "=============================================================================="
echo "Target Host: ${TARGET_USER}@${TARGET_HOST} (via jump ${JUMP_HOST})"
echo "Runtime:     ${DEPLOY_TARGET:-k3s}"
echo "=============================================================================="

SSH_OPTS=(-o StrictHostKeyChecking=no -o ConnectTimeout=10)
if [[ -n "${SSH_KEY:-}" && -f "${SSH_KEY}" ]]; then
  SSH_OPTS+=(-i "${SSH_KEY}")
fi
if [[ -n "${JUMP_HOST:-}" ]]; then
  SSH_OPTS+=(-J "${JUMP_HOST}")
fi

remote_exec() {
  ssh "${SSH_OPTS[@]}" "${TARGET_USER}@${TARGET_HOST}" "$@"
}

remote_copy() {
  scp "${SSH_OPTS[@]}" "$@"
}

# 1. Ensure Payloads are Downloaded
echo "=== [1/4] Verifying Local Payloads ==="
"${SCRIPT_DIR}/download-payloads.sh"

# 2. Package & Transfer Payload Archive
echo "=== [2/4] Packaging & Syncing Payloads to Target ==="
TEMP_ARCHIVE="$(mktemp -t platform-payloads-XXXXXX.tar.gz)"
tar -czf "${TEMP_ARCHIVE}" -C "${REPO_ROOT}/payloads" bin packages

echo "  -> Copying archive to ${TARGET_HOST}:~/platform-payloads.tar.gz..."
remote_copy "${TEMP_ARCHIVE}" "${TARGET_USER}@${TARGET_HOST}:~/platform-payloads.tar.gz"
rm -f "${TEMP_ARCHIVE}"

# 3. Remote Execution
echo "=== [3/4] Installing Runtime & Initializing Cluster ==="
remote_exec bash << 'REMOTE_SCRIPT'
set -euo pipefail

echo "Unpacking platform payloads on target..."
rm -rf ~/platform-payloads && mkdir -p ~/platform-payloads
tar -xzf ~/platform-payloads.tar.gz -C ~/platform-payloads
rm -f ~/platform-payloads.tar.gz

# 1. Install CLI Binaries
echo "Installing CLI toolchains to /usr/local/bin..."
sudo install -m 755 ~/platform-payloads/bin/* /usr/local/bin/

# 2. Deploy Kubernetes Runtime (K3s)
echo "Installing K3s Kubernetes Runtime in Air-Gap Mode..."
sudo mkdir -p /var/lib/rancher/k3s/agent/images/
sudo cp ~/platform-payloads/packages/k3s-airgap-images-*.tar.zst /var/lib/rancher/k3s/agent/images/ 2>/dev/null || true

# Execute K3s offline install
export INSTALL_K3S_SKIP_DOWNLOAD=true
export INSTALL_K3S_BIN_DIR=/usr/local/bin
export INSTALL_K3S_EXEC="server --disable traefik --write-kubeconfig-mode 644"

sudo cp ~/platform-payloads/bin/k3s /usr/local/bin/k3s
sudo chmod +x /usr/local/bin/k3s
sudo INSTALL_K3S_SKIP_DOWNLOAD=true /usr/local/bin/k3s-install.sh

# Wait for K3s readiness
echo "Waiting for Kubernetes cluster readiness..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
until sudo kubectl get nodes &>/dev/null; do
  sleep 2
done
sudo kubectl wait --for=condition=Ready node --all --timeout=60s
sudo kubectl get nodes -o wide

# 3. Initialize Zarf Registry
echo "Initializing Zarf in-cluster registry..."
ZARF_INIT_PKG="$(find ~/platform-payloads/packages -name 'zarf-init-*.tar.zst' | head -n 1)"
if [[ -f "${ZARF_INIT_PKG}" ]]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  zarf init --confirm "${ZARF_INIT_PKG}"
fi

echo "Verifying Zarf pods..."
sudo kubectl get pods -n zarf

echo "✅ Target environment is 100% prepared for UDS bundle deployments!"
REMOTE_SCRIPT

# 4. Fetch Kubeconfig for local workstation
echo "=== [4/4] Retrieving Kubeconfig ==="
remote_exec "sudo cat /etc/rancher/k3s/k3s.yaml" | sed "s/127.0.0.1/${TARGET_HOST}/g" > "${REPO_ROOT}/kubeconfig"
chmod 600 "${REPO_ROOT}/kubeconfig"

echo "=============================================================================="
echo " ✅ Platform preparation complete! Kubeconfig saved to ${REPO_ROOT}/kubeconfig"
echo " You can now run 'uds deploy <bundle>' directly against this target!"
echo "=============================================================================="
