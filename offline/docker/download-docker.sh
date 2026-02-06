#!/usr/bin/env bash
set -euo pipefail

# This script is intended to run on an ONLINE machine.
# It downloads Docker Engine .deb packages for Ubuntu 22.04 (jammy)
# and stores them in offline/docker/packages/.

ARCH="amd64"
UBUNTU_CODENAME="jammy"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="${BASE_DIR}/packages"

mkdir -p "${PKG_DIR}"
cd "${PKG_DIR}"

echo "[INFO] Downloading Docker CE packages for Ubuntu ${UBUNTU_CODENAME} (${ARCH})"

# Official Docker repository (adjust version if needed)
REPO_URL="https://download.docker.com/linux/ubuntu/dists/${UBUNTU_CODENAME}/stable/binary-${ARCH}"

# Package list (minimal set)
PKGS=(
  "containerd.io"
  "docker-ce"
  "docker-ce-cli"
  "docker-buildx-plugin"
  "docker-compose-plugin"
)

for pkg in "${PKGS[@]}"; do
  echo "[INFO] Resolving latest version for ${pkg} ..."
  DEB_URL=$(curl -fsSL "${REPO_URL}/Packages.gz" \
    | gunzip \
    | awk -v pkg="${pkg}" '
        $1 == "Package:" && $2 == pkg {found=1}
        found && $1 == "Filename:" {print $2; exit}
      ')
  if [[ -z "${DEB_URL}" ]]; then
    echo "[ERROR] Could not resolve URL for package ${pkg}"
    exit 1
  fi
  FILE_NAME=$(basename "${DEB_URL}")

  if [[ -f "${FILE_NAME}" ]]; then
    echo "[SKIP] ${FILE_NAME} already exists"
  else
    echo "[DOWNLOAD] ${FILE_NAME}"
    curl -fSL "https://download.docker.com/linux/ubuntu/${DEB_URL}" -o "${FILE_NAME}"
  fi
done

echo "[OK] Docker packages downloaded to ${PKG_DIR}"
echo "Copy the entire 'offline/docker/packages' directory to each air-gapped server."
