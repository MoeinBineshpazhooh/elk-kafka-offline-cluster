# Offline Installation Guide

This repository is designed for offline / air-gapped deployments.
The general strategy is:
1) Prepare artifacts on an online machine (Docker packages, container images, tarballs).
2) Move artifacts to the offline environment.
3) Install Docker offline.
4) Load images from tar files.
5) Run docker compose per role/node.

## 1) On an online machine (artifact preparation)

### Export container images
Create an `images/` directory and export all required images:

```bash
mkdir -p images
# Example:
docker pull docker.elastic.co/elasticsearch/elasticsearch:9.2.4
docker pull docker.elastic.co/kibana/kibana:9.2.4
docker pull docker.elastic.co/logstash/logstash:9.2.4
docker pull apache/kafka:latest
docker pull tchiotludo/akhq:latest
docker pull kafbat/kafka-ui:latest

docker save -o images/elastic-elasticsearch-9.2.4.tar docker.elastic.co/elasticsearch/elasticsearch:9.2.4
docker save -o images/elastic-kibana-9.2.4.tar docker.elastic.co/kibana/kibana:9.2.4
docker save -o images/elastic-logstash-9.2.4.tar docker.elastic.co/logstash/logstash:9.2.4
docker save -o images/apache-kafka-latest.tar apache/kafka:latest
docker save -o images/akhq-latest.tar tchiotludo/akhq:latest
docker save -o images/kafka-ui-latest.tar kafbat/kafka-ui:latest

Export Docker packages (optional, for offline install)
If you cannot use your OS repository offline, download Docker Engine packages for your distro/version and store them under:
offline/docker/ (repo-specific)
or a shared offline artifacts location.
2) Move artifacts into the offline environment
Copy:
images/*.tar
docker offline packages (if needed)
this git repository
Use your approved transfer method (USB, internal mirror, etc.).
3) Install Docker offline
Run the repo helper (if provided) or install packages manually:

sudo bash offline/docker/install-docker-offline.sh

Verify:

docker version
docker compose version

4) Load images offline
Load images from tar:

bash offline/images/load-images.sh

Verify:

docker images | head

5) Start services (by role)
Follow:
scripts/bootstrap-all.sh
component READMEs: kafka/README.md, elasticsearch/README.md, kibana/README.md, logstash/README.md, ui/README.md
