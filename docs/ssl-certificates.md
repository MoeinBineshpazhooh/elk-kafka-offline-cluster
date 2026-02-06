# SSL/TLS Certificates (Elasticsearch HTTP + Transport)

This repository uses Elasticsearch `elasticsearch-certutil` to generate a Certificate Authority (CA) and node certificates for:

- **Transport TLS** (required for secure multi-node clusters)
- **HTTP TLS** (recommended for all client traffic, including Kibana and Logstash)

The cert generation uses `certificates/elasticsearch/instances.yml` as input. [Ref: elasticsearch-certutil] 

## Why two TLS layers?

- **Transport TLS** secures node-to-node communication inside the cluster (port 9300).
- **HTTP TLS** secures client communication to Elasticsearch REST API (port 9200).

## Step 1 — Edit instances.yml

Update:

- `ip`: the real server IP for each node
- `dns`: hostnames used by clients (Kibana, Logstash, operators)

File: `certificates/elasticsearch/instances.yml`

## Step 2 — Generate certificates

Run on an ONLINE machine (or a secure machine that already has the elastic image available):

```bash
cd certificates/elasticsearch
./generate-certs.sh
Output is stored under:

certificates/elasticsearch/generated/

Step 3 — Distribute certificates
3.1 Copy CA certificate to all consumers
Copy:

certificates/elasticsearch/generated/ca/ca.crt

To:

all Elasticsearch nodes

all Kibana nodes

all Logstash nodes

3.2 Copy node certs to each ES node
For each ES node copy:

generated/http/<node>-http.p12

generated/transport/<node>-transport.p12

Example layout on ES nodes (recommended):

text
/opt/elastic/es01/certs/
├── ca.crt
├── es01-http.p12
└── es01-transport.p12
Step 4 — Configure Elasticsearch to use TLS
In elasticsearch.yml (per node):

Enable security

Configure HTTP and Transport keystores

Configure truststore for transport

Example snippet:

text
xpack.security.enabled: true

xpack.security.http.ssl:
  enabled: true
  keystore.path: certs/es01-http.p12

xpack.security.transport.ssl:
  enabled: true
  verification_mode: certificate
  keystore.path: certs/es01-transport.p12
  truststore.path: certs/es01-transport.p12
Step 5 — Configure Kibana / Logstash to trust the CA
Kibana
Mount ca.crt into Kibana container and set:

ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES=/path/to/ca.crt

Logstash
Mount ca.crt into Logstash container and set:

cacert => "/path/to/ca.crt"

Security Notes
Keep the CA private key (ca.key) secret. Do not store it on every node.

For production, consider using an internal PKI and rotate certificates periodically.
