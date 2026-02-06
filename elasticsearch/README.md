# Elasticsearch (3-node, TLS + Security)

This folder contains docker-compose files and per-node configuration for a 3-node Elasticsearch cluster.

## Node roles (Option B)

All nodes are:
- master-eligible
- data
- ingest

## Prerequisites

1) System tuning (on each ES node):

- `vm.max_map_count` must be set
- `nofile` limits should be high

See: `scripts/system-tuning.md`

2) Certificates

Generate TLS certificates:

```bash
cd certificates/elasticsearch
./generate-certs.sh

Copy files to each node:
/opt/elastic/es01/certs/ must contain:
ca.crt
es01-http.p12
es01-transport.p12
Repeat similarly for es02 and es03.
Secrets
Create env/elastic.env from env/elastic.env.example and set a strong ELASTIC_PASSWORD.
Start order (important)
Start nodes sequentially:
es01
On es01 host:

cd elasticsearch
set -a; source ../env/elastic.env; set +a
docker compose -f docker-compose.es01.yml up -d
docker logs -f es01

es02
On es02 host:

cd elasticsearch
set -a; source ../env/elastic.env; set +a
docker compose -f docker-compose.es02.yml up -d
docker logs -f es02

es03
On es03 host:

cd elasticsearch
set -a; source ../env/elastic.env; set +a
docker compose -f docker-compose.es03.yml up -d
docker logs -f es03

Verify
From any node:

# Cluster health
curl -k -u elastic:${ELASTIC_PASSWORD} https://10.10.4.101:9200/_cluster/health?pretty

# Nodes
curl -k -u elastic:${ELASTIC_PASSWORD} https://10.10.4.101:9200/_cat/nodes?v

Expected:
status: green (or yellow initially until replicas are allocated)
3 nodes listed
Passwords
You can reset built-in user passwords from inside a running ES container:

docker exec -it es01 bin/elasticsearch-reset-password -u elastic -i
docker exec -it es01 bin/elasticsearch-reset-password -u kibana_system -a -y
docker exec -it es01 bin/elasticsearch-reset-password -u logstash_system -a -y

