<div align="center">

# Enterprise Observability Platform

### Air-Gapped Elasticsearch + Kafka Observability Stack

**Filebeat → Kafka KRaft → Logstash → Elasticsearch → Kibana**

[![Elastic](https://img.shields.io/badge/Elastic-9.2.4-005571?logo=elastic)](https://www.elastic.co/)
[![Kafka](https://img.shields.io/badge/Kafka-KRaft-231F20?logo=apachekafka)](https://kafka.apache.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Air-Gapped](https://img.shields.io/badge/Deployment-Air--Gapped-success)](#air-gapped-by-design)

A production-oriented reference implementation for deploying an observable log-ingestion platform in **restricted and air-gapped environments**, with explicit security boundaries, durable Kafka transport, Elasticsearch lifecycle management, and isolated pipeline configuration.

</div>

---

## Architecture

```text
                         ┌──────────────────────┐
                         │   Application Logs    │
                         │   JSON / NDJSON       │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │      Filebeat        │
                         │     filestream       │
                         │ persistent registry  │
                         └──────────┬───────────┘
                                    │ SASL/PLAIN
                                    ▼
                 ┌────────────────────────────────────┐
                 │             Kafka KRaft            │
                 │                                    │
                 │  Controller 01  Controller 02      │
                 │  Controller 03                     │
                 │                                    │
                 │  Broker 01  Broker 02  Broker 03  │
                 └────────────────┬───────────────────┘
                                  │ SASL/PLAIN
                                  ▼
                         ┌──────────────────────┐
                         │      Logstash        │
                         │  isolated pipelines │
                         │   Kafka → ES         │
                         └──────────┬───────────┘
                                    │ HTTPS / TLS
                                    ▼
                 ┌────────────────────────────────────┐
                 │          Elasticsearch 3-node      │
                 │       Security + TLS + ILM         │
                 │       rollover + retention         │
                 └────────────────┬───────────────────┘
                                  │ HTTPS
                                  ▼
                         ┌──────────────────────┐
                         │       Kibana          │
                         │ Search / Dashboards   │
                         └──────────────────────┘
```

See [`docs/end-to-end-flow.md`](docs/end-to-end-flow.md) for the detailed data path and failure boundaries.

## What This Repository Demonstrates

- **Air-gapped deployment** — offline Docker packages and preloaded container images.
- **Kafka KRaft** — controller quorum without ZooKeeper, with broker-level ACLs.
- **SASL authentication** — explicit Kafka authentication for producers and consumers.
- **Filebeat filestream** — persistent registry and tuned file harvesting.
- **Configuration isolation** — independent Filebeat input files and Logstash pipelines.
- **Elasticsearch security** — TLS for HTTP and transport traffic.
- **ILM + rollover** — size/age based rollover with controlled retention.
- **Operational verification** — health and configuration validation scripts.
- **Secrets hygiene** — public examples contain placeholders, not real credentials.

## Repository Layout

```text
.
├── certificates/                 # TLS certificate generation material
├── docs/                         # Architecture and operational documentation
├── elasticsearch/                # 3-node Elasticsearch cluster + ILM
│   ├── config/                   # Node-specific ES configuration
│   ├── ilm/                      # Lifecycle policy
│   └── templates/                # Index template + rollover bootstrap
├── env/                          # Sanitized *.env.example files
├── filebeat/                     # File ingestion layer
│   ├── config/                   # Shared Filebeat runtime configuration
│   └── inputs/                   # Isolated input definitions
├── inventory/                    # Example host layout
├── kafka/                        # KRaft controllers, brokers and ACLs
│   ├── config/                   # Node-specific properties
│   ├── security/                 # ACL and client security material
│   └── topics/                   # Example topic definitions
├── kibana/                       # Kibana deployment and configuration
├── logstash/                     # Isolated Kafka → Elasticsearch pipelines
│   ├── config/                   # Logstash runtime configuration
│   └── pipeline/                 # Individual pipeline definitions
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
        ├── pipeline A → pipeline/a.conf
        └── pipeline B → pipeline/b.conf
```

Each pipeline can be mounted independently on its Logstash host, which keeps ownership, troubleshooting, and lifecycle boundaries clear.

## Elasticsearch Lifecycle

The example log stream uses an ILM policy with:

| Phase | Policy |
|---|---|
| Hot | Rollover at 10 GB primary shard size or 1 day |
| Warm | After 1 day |
| Delete | After 30 days |

The rollover alias is used as the stable write target. The initial index is bootstrapped separately so that only the intended write index receives the `is_write_index` flag.

## Air-Gapped by Design

Runtime hosts are not expected to access the public internet.

```text
Internet-connected preparation host
            │
            ├── Docker packages
            ├── container image bundle
            ├── certificates / approved artifacts
            │
            ▼
      Controlled offline media
            │
            ▼
      Air-gapped environment
            │
            ├── Kafka
            ├── Filebeat
            ├── Logstash
            ├── Elasticsearch
            └── Kibana
```

The `offline/` directory contains the preparation workflow. Images should be validated before being transferred into the restricted environment.

## Deployment Sequence

For a clean installation, use the following dependency order:

1. Prepare offline Docker packages and images.
2. Generate and distribute Elasticsearch certificates.
3. Deploy the three Kafka controllers.
4. Deploy the three Kafka brokers.
5. Create the required Kafka topics and ACLs.
6. Deploy the Elasticsearch nodes.
7. Bootstrap the Elasticsearch rollover index.
8. Deploy Filebeat and verify Kafka publication.
9. Deploy Logstash and verify Kafka consumption.
10. Deploy Kibana and validate search/dashboard access.
11. Run the configuration and health checks.

Component-specific instructions live in each component's README.

## Verification

Validate Compose configuration before deployment:

```bash
./scripts/validate-configuration.sh
```

Then verify each boundary independently:

```text
Filebeat
  └─ events published → Kafka

Kafka
  └─ topic + ACL + consumer group healthy

Logstash
  └─ events consumed → Elasticsearch

Elasticsearch
  └─ alias + ILM + documents healthy

Kibana
  └─ data view / dashboards available
```

## Operational Principles

### Durable boundaries

Kafka separates file ingestion from downstream processing. A temporary Logstash or Elasticsearch outage does not require the application to remain connected to the entire observability stack.

### Least privilege

Clients receive only the Kafka permissions required for their role. Administrative access is kept separate from application and pipeline identities.

### Explicit failure domains

Each major component has its own configuration, storage, credentials, and deployment unit. This makes failures easier to isolate and recovery procedures easier to reason about.

### Reproducibility

The repository favors declarative configuration and deterministic bootstrap steps over manual changes made inside running containers.

## Documentation

- [`docs/end-to-end-flow.md`](docs/end-to-end-flow.md) — complete ingestion path and failure boundaries
- [`elasticsearch/README.md`](elasticsearch/README.md) — Elasticsearch cluster
- [`kafka/README.md`](kafka/README.md) — Kafka KRaft and ACLs
- [`filebeat/README.md`](filebeat/README.md) — Filebeat ingestion
- [`logstash/README.md`](logstash/README.md) — Logstash pipelines
- [`elasticsearch/ilm/README.md`](elasticsearch/ilm/README.md) — lifecycle management
- [`elasticsearch/templates/README.md`](elasticsearch/templates/README.md) — index templates and rollover

## Portfolio Scope

This repository is intentionally presented as a **sanitized reference architecture**. Network addresses, topic names, usernames, passwords, host paths, and other environment-specific identifiers are fictional placeholders.

The goal is to demonstrate the engineering approach: secure transport boundaries, resilient log delivery, configuration isolation, lifecycle management, offline operations, and operational troubleshooting.
