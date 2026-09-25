#!/usr/bin/env bash
# ==============================================================================
# Platform Toolchain Version Updater
# ==============================================================================
# Queries GitHub release APIs for the latest versions of UDS, Zarf, Lula, Kubectl,
# and K3s, and updates versions.env.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSIONS_FILE="${REPO_ROOT}/versions.env"

echo "=============================================================================="
echo "          CHECKING LATEST PLATFORM TOOLCHAIN RELEASES                         "
echo "=============================================================================="

get_latest_gh_release() {
  local repo="$1"
  if command -v gh &>/dev/null; then
    gh release view -R "${repo}" --json tagName -q .tagName 2>/dev/null || true
  else
    curl -sSf "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true
  fi
}

echo "Querying GitHub release endpoints..."

LATEST_UDS="$(get_latest_gh_release "defenseunicorns/uds-cli")"
LATEST_ZARF="$(get_latest_gh_release "zarf-dev/zarf")"
LATEST_LULA="$(get_latest_gh_release "defenseunicorns/lula")"
LATEST_K3S="$(get_latest_gh_release "k3s-io/k3s")"
LATEST_KUBECTL="$(curl -sSL https://dl.k8s.io/release/stable.txt 2>/dev/null || echo "v1.31.0")"

echo "Latest Versions Found:"
echo "  • UDS CLI:    ${LATEST_UDS:-[current]}"
echo "  • Zarf CLI:   ${LATEST_ZARF:-[current]}"
echo "  • Lula CLI:   ${LATEST_LULA:-[current]}"
echo "  • Kubectl:    ${LATEST_KUBECTL:-[current]}"
echo "  • K3s:        ${LATEST_K3S:-[current]}"

# Source current
source "${VERSIONS_FILE}"

NEW_UDS="${LATEST_UDS:-${UDS_VERSION}}"
NEW_ZARF="${LATEST_ZARF:-${ZARF_VERSION}}"
NEW_LULA="${LATEST_LULA:-${LULA_VERSION}}"
NEW_KUBECTL="${LATEST_KUBECTL:-${KUBECTL_VERSION}}"
NEW_K3S="${LATEST_K3S:-${K3S_VERSION}}"

cat << EOF > "${VERSIONS_FILE}"
# ==============================================================================
# Platform Toolchains and Cluster Runtime Versions
# ==============================================================================
# Central source of truth for tool versions downloaded and deployed by uds-platform-prep.
# Updated on: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# ==============================================================================

ARCH="amd64"

# CLI Toolchains
UDS_VERSION="${NEW_UDS}"
ZARF_VERSION="${NEW_ZARF}"
KUBECTL_VERSION="${NEW_KUBECTL}"
LULA_VERSION="${NEW_LULA}"

# Kubernetes Runtimes & Airgap Assets
K3S_VERSION="${NEW_K3S}"
RKE2_VERSION="${RKE2_VERSION}"
TALOS_VERSION="${TALOS_VERSION}"
EOF

echo "=============================================================================="
echo " ✅ ${VERSIONS_FILE} updated successfully!"
echo " Run './scripts/download-payloads.sh' or 'make download' to fetch updated assets."
echo "=============================================================================="
