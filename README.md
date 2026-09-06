<div align="center">

# Enterprise Observability Platform

### Air-Gapped Elasticsearch + Kafka Observability Stack

**Filebeat → Kafka KRaft → Logstash → Elasticsearch → Kibana**

[![Elastic](https://img.shields.io/badge/Elastic-9.2.4-005571?logo=elastic)](https://www.elastic.co/)
[![Kafka](https://img.shields.io/badge/Kafka-KRaft-231F20?logo=apachekafka)](https://kafka.apache.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Air-Gapped](https://img.shields.io/badge/Deployment-Air--Gapped-success)](#air-gapped-by-design)

A production-oriented reference implementation for deploying an observable log-ingestion platform in **restricted and air-gapped environments**, with explicit security boundaries, durable Kafka transport, Elasticsearch lifecycle management, isolated pipeline configuration, and a portable Kibana dashboard bundle.

</div>

---

## Architecture

```text
Application Logs → Filebeat → Kafka KRaft → Logstash → Elasticsearch → Kibana
```

The detailed architecture and failure boundaries are documented in [`docs/end-to-end-flow.md`](docs/end-to-end-flow.md).

## What This Repository Demonstrates

- **Air-gapped deployment** — offline Docker packages and preloaded container images.
- **Kafka KRaft** — controller quorum without ZooKeeper, with broker-level ACLs.
- **SASL authentication** — explicit Kafka authentication for producers and consumers.
- **Filebeat filestream** — persistent registry and tuned file harvesting.
- **Configuration isolation** — independent Filebeat input files and Logstash pipelines.
- **Elasticsearch security** — TLS for HTTP and transport traffic.
- **ILM + rollover** — size/age based rollover with controlled retention.
- **Kibana Saved Objects** — portable Data View and operational dashboard bundle.
- **Operational verification** — Compose and Saved Object validation scripts.
- **Secrets hygiene** — public examples contain placeholders, not real credentials.

## Repository Layout

```text
.
├── certificates/                 # TLS certificate generation material
├── docs/                         # Architecture and operational documentation
├── elasticsearch/                # 3-node Elasticsearch cluster + ILM
├── env/                          # Sanitized *.env.example files
├── filebeat/                     # File ingestion layer
│   ├── config/                   # Shared Filebeat runtime configuration
│   └── inputs/                   # Isolated input definitions
├── inventory/                    # Example host layout
├── kafka/                        # KRaft controllers, brokers and ACLs
├── kibana/                       # Kibana deployment + Saved Objects
│   ├── saved-objects.ndjson      # Portable dashboard bundle
│   └── saved-objects/            # Import/versioning documentation
├── logstash/                     # Isolated Kafka → Elasticsearch pipelines
├── offline/                      # Offline package/image preparation
├── scripts/                      # Operational utilities
└── ui/                           # Optional Kafka management UIs
```

## Security Model

### Kafka

Kafka uses **SASL/PLAIN** authentication with explicit principals and ACLs. Producer and consumer permissions are separated according to responsibility.

> `SASL_PLAINTEXT` authenticates clients but does **not** encrypt traffic. For environments requiring confidentiality in transit, use TLS-enabled Kafka listeners together with SASL.

### Elasticsearch

Elasticsearch is configured with security enabled and TLS for both HTTP and transport communication. Certificates are generated separately from the runtime deployment.

### Secrets

Never commit production credentials. Copy an example environment file locally, replace every `CHANGE_ME_*` value, and keep the real file outside version control.

## Configuration Isolation

The platform deliberately avoids one giant configuration file.

### Filebeat

```text
filebeat/config/filebeat.yml
        │
        └── loads → filebeat/inputs/*.yml
```

A new application or log source can therefore be introduced as an independent input definition without modifying the shared Kafka output configuration.

### Logstash

```text
logstash/config/pipelines.yml
        │
        └── isolated pipeline definitions
```

Each pipeline can be mounted independently on its Logstash host, keeping ownership, troubleshooting, and lifecycle boundaries clear.

## Elasticsearch Lifecycle

The example log stream uses an ILM policy with:

| Phase | Policy |
|---|---|
| Hot | Rollover at 10 GB primary shard size or 1 day |
| Warm | After 1 day |
| Delete | After 30 days |

The rollover alias is used as the stable write target. The initial index is bootstrapped separately so that only the intended write index receives the `is_write_index` flag.

## Kibana Dashboard

The repository includes a single NDJSON bundle containing:

- `demo-logs-*` Data View with `@timestamp` as the time field
- Events-over-time visualization
- Events-by-service-source visualization
- Events-by-log-level visualization
- Enterprise Observability dashboard combining the visualizations

Import it from **Stack Management → Saved Objects → Import**:

```text
kibana/saved-objects.ndjson
```

Detailed import and versioning guidance is in [`kibana/saved-objects/README.md`](kibana/saved-objects/README.md).

Because Kibana Saved Objects are version-sensitive, the bundle is intentionally tied to the repository's Kibana 9.2.x target. When upgrading Kibana, prefer exporting the objects from the target Kibana version and replacing the bundle rather than manually editing generated migration metadata.

## Air-Gapped by Design

Runtime hosts are not expected to access the public internet.

```text
Preparation host → controlled offline media → air-gapped environment
```

The `offline/` directory contains the preparation workflow. Images should be validated before transfer into the restricted environment.

## Deployment Sequence

1. Prepare offline Docker packages and images.
2. Generate and distribute Elasticsearch certificates.
3. Deploy the three Kafka controllers.
4. Deploy the three Kafka brokers.
5. Create the required Kafka topics and ACLs.
6. Deploy the Elasticsearch nodes.
7. Bootstrap the Elasticsearch rollover index.
8. Deploy Filebeat and verify Kafka publication.
9. Deploy Logstash and verify Kafka consumption.
10. Deploy Kibana and import the Saved Object bundle.
11. Run the configuration and Saved Object validation checks.

## Verification

Validate Compose configuration:

```bash
./scripts/validate-configuration.sh
```

Validate the Kibana NDJSON structure:

```bash
bash ./scripts/validate-kibana-saved-objects.sh
```

Then verify each boundary independently:

```text
Filebeat       → events published to Kafka
Kafka          → topic + ACL + consumer group healthy
Logstash       → events consumed and indexed
Elasticsearch  → alias + ILM + documents healthy
Kibana         → Data View + dashboard available
```

## Documentation

- [`docs/end-to-end-flow.md`](docs/end-to-end-flow.md) — complete ingestion path and failure boundaries
- [`elasticsearch/README.md`](elasticsearch/README.md) — Elasticsearch cluster
- [`kafka/README.md`](kafka/README.md) — Kafka KRaft and ACLs
- [`filebeat/README.md`](filebeat/README.md) — Filebeat ingestion
- [`logstash/README.md`](logstash/README.md) — Logstash pipelines
- [`elasticsearch/ilm/README.md`](elasticsearch/ilm/README.md) — lifecycle management
- [`elasticsearch/templates/README.md`](elasticsearch/templates/README.md) — index templates and rollover
- [`kibana/saved-objects/README.md`](kibana/saved-objects/README.md) — Saved Object import/versioning

## Portfolio Scope

This repository is intentionally presented as a **sanitized reference architecture**. Network addresses, topic names, usernames, passwords, host paths, and other environment-specific identifiers are fictional placeholders.

The goal is to demonstrate the engineering approach: secure transport boundaries, resilient log delivery, configuration isolation, lifecycle management, offline operations, operational dashboards, and troubleshooting.
