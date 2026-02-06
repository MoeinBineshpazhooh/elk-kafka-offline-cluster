# Kibana (HTTP and HTTPS options)

This folder contains docker-compose files for Kibana nodes using host networking.

Two variants are provided for each node:

- HTTP:
  - docker-compose.kibana01.yml
  - docker-compose.kibana02.yml

- HTTPS (Kibana serves TLS on 5601):
  - docker-compose.kibana01.https.yml
  - docker-compose.kibana02.https.yml

## Prerequisites

1) Elasticsearch must be up with HTTPS enabled.
2) Set password for the built-in user `kibana_system`.
3) Create `env/kibana.env` from `env/kibana.env.example`.

## Certificates

Kibana must trust Elasticsearch CA:
- Mount CA cert into the container at:
  `/usr/share/kibana/config/certs/ca/ca.crt`

For Kibana HTTPS mode you also need a server certificate + key:
- `/usr/share/kibana/config/certs/server/kibana.crt`
- `/usr/share/kibana/config/certs/server/kibana.key`

## Host paths (recommended)

On kibana01:
- /opt/elastic/kibana01/certs/ca/ca.crt
- /opt/elastic/kibana01/certs/server/kibana.crt (only for HTTPS mode)
- /opt/elastic/kibana01/certs/server/kibana.key (only for HTTPS mode)

On kibana02:
- /opt/elastic/kibana02/certs/ca/ca.crt
- /opt/elastic/kibana02/certs/server/kibana.crt (only for HTTPS mode)
- /opt/elastic/kibana02/certs/server/kibana.key (only for HTTPS mode)

Make sure Kibana can read these files (permissions).

## Start

HTTP mode (kibana01 host):
```bash
cd kibana
docker compose -f docker-compose.kibana01.yml up -d
docker logs -f kibana01

HTTPS mode (kibana01 host):

cd kibana
docker compose -f docker-compose.kibana01.https.yml up -d
docker logs -f kibana01

Repeat similarly for kibana02.
Verify
Kibana API status:
HTTP mode: http://<kibana-host>:5601/api/status
HTTPS mode: https://<kibana-host>:5601/api/status
