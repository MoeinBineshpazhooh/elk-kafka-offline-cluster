#!/usr/bin/env bash
set -euo pipefail

# Install Docker Engine + docker compose plugin from local .deb files.
# Run this on each AIR-GAPPED server after copying the 'packages' directory.

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="${BASE_DIR}/packages"

if [[ ! -d "${PKG_DIR}" ]]; then
  echo "[ERROR] Package directory not found: ${PKG_DIR}"
  echo "Copy offline/docker/packages from the online machine first."
  exit 1
fi

echo "[INFO] Installing Docker from local packages in ${PKG_DIR}"

sudo apt-get update -y || true
sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

# Install all .deb files
sudo dpkg -i "${PKG_DIR}"/*.deb || true

# Fix any missing dependencies
sudo apt-get install -f -y

# Enable & start Docker
sudo systemctl enable docker
sudo systemctl start docker

echo "[INFO] Docker version:"
docker --version || true
echo "[INFO] Docker Compose plugin version:"
docker compose version || true

echo "[OK] Docker installed offline successfully."
