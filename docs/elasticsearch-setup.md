# Elasticsearch Setup (Self-managed, Docker Compose)

This document describes common operational settings and checks for running Elasticsearch nodes with Docker Compose.

## Kernel / OS requirements (Linux)

### vm.max_map_count
Set vm.max_map_count on each Elasticsearch host:

```bash
sudo sysctl -w vm.max_map_count=262144

To make it persistent:

echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-elasticsearch.conf
sudo sysctl --system

File descriptors (recommended)
Check open files limit:

ulimit -n

If it's low, increase for your shell/service according to your OS guidelines.
TLS and HTTPS
If Elasticsearch HTTP is HTTPS-enabled, clients must:
Use https://...
Trust the CA used to sign Elasticsearch HTTP certificates
Example curl with CA

curl --cacert /path/to/ca.crt -u elastic:<PASSWORD> https://10.10.4.101:9200

Password reset (built-in users)
Run inside an Elasticsearch container:

docker exec -it es01 bash
bin/elasticsearch-reset-password -u elastic -i
bin/elasticsearch-reset-password -u kibana_system -a -y
bin/elasticsearch-reset-password -u logstash_system -a -y

