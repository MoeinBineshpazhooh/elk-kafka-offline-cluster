# Offline Docker Installation

This document explains how to install Docker Engine and the Docker Compose plugin in an **air-gapped** (offline) environment using local `.deb` packages.

## What you get

After completing this guide on each target server, you should have:

- Docker Engine installed and running (`docker`)
- Docker Compose plugin installed (`docker compose`)
- Docker service enabled to start automatically on boot

## Folder layout

This repository expects the following files:

- `offline/docker/download-docker.sh` (run on an **online** machine)
- `offline/docker/install-docker-offline.sh` (run on each **air-gapped** server)
- `offline/docker/packages/` (contains the downloaded `.deb` packages)

Example:

offline/docker/
├── download-docker.sh
├── install-docker-offline.sh
├── install-docker-offline.md
└── packages/
├── containerd.io_.deb
├── docker-ce_.deb
├── docker-ce-cli_.deb
├── docker-buildx-plugin_.deb
└── docker-compose-plugin_*.deb

## Step 1 — Download packages (ONLINE machine)

On a machine that has internet access:


cd offline/docker
chmod +x download-docker.sh
./download-docker.sh

This will download all required .deb packages into:
offline/docker/packages/
Copy the entire offline/docker/ directory (including the packages/ folder) to your offline media (USB).
Step 2 — Install Docker (AIR-GAPPED server)
On each offline target server:
Copy the folder to the server, for example to /root/elk-offline/offline/docker/
Run the offline installer script:

cd offline/docker
chmod +x install-docker-offline.sh
./install-docker-offline.sh

Step 3 — Verify installation
Check versions:
docker --version
docker compose version

Check service status:

systemctl status docker --no-pager

Run a quick test:

docker run --rm hello-world

If hello-world image is not available offline, skip this test. Your deployment will still work after you load images using offline/images/load-images.sh.
Optional — Allow non-root user to run Docker
If you want a normal user (e.g. drp) to run Docker without sudo

sudo usermod -aG docker drp
newgrp docker
docker ps

Troubleshooting
dpkg dependency errors
If dpkg -i fails due to missing dependencies, the installer script automatically runs:

sudo apt-get install -f -y

Docker daemon not running
Check logs:

journalctl -u docker --no-pager -n 200

Restart Docker:

sudo systemctl restart docker

Kernel / sysctl prerequisites
Some components (e.g. Elasticsearch) require additional sysctl settings such as vm.max_map_count.
See scripts/system-tuning.md.
