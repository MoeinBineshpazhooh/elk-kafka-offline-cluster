# Elasticsearch TLS Certificates

This folder contains scripts and input files to generate TLS certificates for:

- Elasticsearch HTTP layer (clients -> Elasticsearch)
- Elasticsearch transport layer (node -> node)

We use `elasticsearch-certutil` to generate a local CA and per-node certificates.

## Files

- `instances.yml` - list of nodes, IPs and DNS names used in certificates
- `generate-certs.sh` - generates CA + HTTP/Transport certificates
- `generated/` - output folder (created after generation)

## Usage (ONLINE machine)

1) Make sure Docker is installed and you can pull/run Elasticsearch image:

```bash
docker pull elastic/elasticsearch:9.2.4

Update instances.yml with your real IPs and DNS names.
Generate certificates:
bash
cd certificates/elasticsearch
./generate-certs.sh

Distribute files to Elasticsearch nodes:
Copy generated/ca/ca.crt to:
Elasticsearch nodes
Kibana nodes
Logstash nodes
Copy node-specific .p12 files:
generated/transport/es01-transport.p12 to es01
generated/http/es01-http.p12 to es01
etc.
IMPORTANT: Keep generated/ca/ca.key secret and do not copy it to production nodes.
See docs/ssl-certificates.md for more details.
