#!/usr/bin/env bash
# ==============================================================================
# Air-Gap Payload & Toolchain Downloader
# ==============================================================================
# Downloads CLI binaries, Zarf init packages, and Kubernetes airgap bundles
# based on pinned versions in versions.env.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source version config
source "${REPO_ROOT}/versions.env"

BIN_DIR="${REPO_ROOT}/payloads/bin"
PKG_DIR="${REPO_ROOT}/payloads/packages"

mkdir -p "${BIN_DIR}" "${PKG_DIR}"

echo "=============================================================================="
echo "          DOWNLOADING AIR-GAP PAYLOADS & TOOLCHAINS                          "
echo "=============================================================================="

# Helper for curl download with fallback to local copy
download_or_copy() {
  local target_file="$1"
  local url="$2"
  local local_fallback="${3:-}"

  if [[ -f "${target_file}" && -s "${target_file}" ]]; then
    echo "  -> [EXISTS] $(basename "${target_file}")"
    return 0
  fi

  if [[ -n "${local_fallback}" && -f "${local_fallback}" ]]; then
    echo "  -> [LOCAL CACHE] Copying from ${local_fallback}"
    cp "${local_fallback}" "${target_file}"
    return 0
  fi

  echo "  -> [DOWNLOADING] $(basename "${target_file}") from ${url}..."
  if ! curl -fsSL --progress-bar -o "${target_file}" "${url}"; then
    echo "  ⚠️  Warning: Failed to download ${url}"
    rm -f "${target_file}"
    return 1
  fi
}

# 1. Download CLI Binaries
echo "=== [1/3] CLI Toolchains (UDS, Zarf, Kubectl) ==="

# UDS CLI
download_or_copy "${BIN_DIR}/uds" \
  "https://github.com/defenseunicorns/uds-cli/releases/download/${UDS_VERSION}/uds-cli_${UDS_VERSION}_Linux_${ARCH}" \
  "$(command -v uds || echo "/usr/local/bin/uds")" || true
chmod +x "${BIN_DIR}/uds" 2>/dev/null || true

# Zarf CLI
download_or_copy "${BIN_DIR}/zarf" \
  "https://github.com/zarf-dev/zarf/releases/download/${ZARF_VERSION}/zarf_${ZARF_VERSION}_Linux_${ARCH}" \
  "$(command -v zarf || echo "${HOME}/.local/bin/zarf")" || true
chmod +x "${BIN_DIR}/zarf" 2>/dev/null || true

# Kubectl
download_or_copy "${BIN_DIR}/kubectl" \
  "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
  "$(command -v kubectl || echo "${HOME}/.local/bin/kubectl")" || true
chmod +x "${BIN_DIR}/kubectl" 2>/dev/null || true

# Lula CLI
download_or_copy "${BIN_DIR}/lula" \
  "https://github.com/defenseunicorns-labs/lula1/releases/download/${LULA_VERSION}/lula_${LULA_VERSION}_Linux_${ARCH}" \
  "$(command -v lula || echo "${HOME}/.local/bin/lula")" || true
chmod +x "${BIN_DIR}/lula" 2>/dev/null || true

# 2. Download Zarf Init Package
echo "=== [2/3] Zarf Cluster Init Package ==="
download_or_copy "${PKG_DIR}/zarf-init-${ARCH}-${ZARF_VERSION}.tar.zst" \
  "https://github.com/zarf-dev/zarf/releases/download/${ZARF_VERSION}/zarf-init-${ARCH}-${ZARF_VERSION}.tar.zst" \
  "${HOME}/.zarf-cache/zarf-init-${ARCH}-${ZARF_VERSION}.tar.zst" || true

# 3. Download K3s Airgap Bundle
echo "=== [3/3] K3s Air-Gap Runtime Package ==="
# K3s Binary
K3S_URL_ENCODED="${K3S_VERSION/+/%2B}"
download_or_copy "${BIN_DIR}/k3s" \
  "https://github.com/k3s-io/k3s/releases/download/${K3S_URL_ENCODED}/k3s" \
  ""
chmod +x "${BIN_DIR}/k3s"

# K3s Install Script
download_or_copy "${BIN_DIR}/k3s-install.sh" \
  "https://raw.githubusercontent.com/k3s-io/k3s/${K3S_URL_ENCODED}/install.sh" \
  ""
chmod +x "${BIN_DIR}/k3s-install.sh"

# K3s Airgap Images
download_or_copy "${PKG_DIR}/k3s-airgap-images-${ARCH}.tar.zst" \
  "https://github.com/k3s-io/k3s/releases/download/${K3S_URL_ENCODED}/k3s-airgap-images-${ARCH}.tar.zst" \
  ""

echo "=============================================================================="
echo " All air-gap payloads downloaded successfully into payloads/ !"
echo "=============================================================================="
