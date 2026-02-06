# Architecture Overview

This repository provides an end-to-end, air-gapped (offline) deployment of an ELK Stack + Kafka (KRaft) cluster across 10 servers.

## Goals

- Run in a fully isolated network (no direct internet access).
- Install Docker offline and load all container images from a local bundle.
- Run a secured Elasticsearch cluster using TLS for both HTTP and transport.
- Ingest logs through Kafka and Logstash into Elasticsearch, and visualize in Kibana.

## Topology Summary (10 Servers)

### Elasticsearch (3 nodes) — Option B
All Elasticsearch nodes are:
- master-eligible
- data
- ingest

This keeps the architecture simple and reliable for small-to-medium environments.

### Kafka (KRaft)
- 3 controllers (quorum): `process.roles=controller`
- 2 brokers (data): `process.roles=broker`

### Ingestion and UI
- 2 nodes running Kibana + Logstash (can scale horizontally)
- 1 node running Kafka UIs (optional; can be colocated with kibana01)

## Data Flow

Producers (Filebeat/Apps/Agents) -> Kafka topics -> Logstash pipelines -> Elasticsearch indices -> Kibana dashboards

## Service Ports

- Elasticsearch HTTP: 9200
- Elasticsearch Transport: 9300
- Kibana: 5601
- Logstash HTTP API: 9600
- Kafka Broker: 9092
- Kafka Controller: 9093
- AKHQ: 8080
- Kafka UI: 8081

## Startup Order (Important)

1. Install Docker offline on all nodes.
2. Load the image bundle on all nodes (or at least on nodes that run containers).
3. Generate TLS certificates for Elasticsearch.
4. Start Kafka controllers (3 nodes).
5. Start Kafka brokers (2 nodes), format storage, and create topics.
6. Start Elasticsearch nodes (es01 then es02 then es03).
7. Set/reset Elastic built-in user passwords (elastic, kibana_system, etc).
8. Start Kibana and Logstash nodes.
9. (Optional) Start AKHQ and Kafka UI.

## Notes

- All docker-compose files are designed to work with `network_mode: host` to simplify networking in isolated environments.
- Secrets are stored in `.env` files (gitignored). Only `.env.example` templates are committed.
