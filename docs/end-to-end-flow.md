# End-to-End Observability Flow

This document describes the complete ingestion path represented by the portfolio configuration.

```text
Application log files
        │
        ▼
┌──────────────────────┐
│      Filebeat        │
│  filestream inputs   │
│  local registry      │
└──────────┬───────────┘
           │ SASL/PLAIN
           ▼
┌──────────────────────┐
│     Kafka KRaft      │
│  3 controllers       │
│  3 brokers            │
└──────────┬───────────┘
           │ SASL/PLAIN
           ▼
┌──────────────────────┐
│      Logstash        │
│ isolated pipelines   │
│ Kafka → Elasticsearch│
└──────────┬───────────┘
           │ HTTPS/TLS
           ▼
┌──────────────────────┐
│   Elasticsearch      │
│ ILM + rollover       │
│ TLS + security       │
└──────────┬───────────┘
           │ HTTPS
           ▼
┌──────────────────────┐
│       Kibana         │
│ dashboards / search  │
└──────────────────────┘
```

## Design Principles

### 1. Filebeat owns file ingestion

Filebeat watches application log files using `filestream`. The registry is persisted so offsets survive container restarts.

### 2. Input configuration is isolated

Each log source can be represented by a separate file under `filebeat/inputs/`. The main configuration loads these files through `filebeat.config.inputs` rather than requiring one large configuration file.

### 3. Kafka is the durable transport boundary

Filebeat publishes events to a dedicated example Kafka topic. Kafka provides buffering between producers and Logstash and allows the downstream processing layer to be restarted independently.

### 4. Authentication is explicit

Both Filebeat and Logstash use SASL/PLAIN for Kafka authentication. The repository contains only placeholders for credentials.

> SASL/PLAIN authenticates clients but does not provide confidentiality by itself. Use TLS-enabled Kafka listeners when encryption in transit is required.

### 5. Logstash is isolated from ingestion configuration

Logstash consumes the Kafka topic through an isolated pipeline configuration and writes to the Elasticsearch rollover alias rather than hard-coding daily index names.

### 6. Elasticsearch owns lifecycle management

The index template associates the log stream with the ILM policy and rollover alias. The initial write index is bootstrapped separately so only the intended current index receives the write flag.

## Failure Boundaries

| Failure | Expected behavior |
|---|---|
| Application temporarily stops writing | Filebeat waits for new events |
| Filebeat restarts | Persistent registry preserves state |
| Logstash restarts | Kafka consumer group resumes consumption |
| Elasticsearch temporarily unavailable | Logstash retries output delivery |
| One Kafka broker fails | Kafka remains available when quorum/ISR requirements are satisfied |
| Old Elasticsearch index reaches rollover threshold | ILM creates the next generation through the rollover alias |

## Air-Gapped Deployment Model

The repository is designed for environments where runtime hosts do not have internet access. Container images, operating-system packages, and required artifacts are prepared outside the isolated network and transferred through controlled offline media.

No runtime component should require access to a public package registry or external service for normal operation.
