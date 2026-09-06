<div align="center">

# 🛰️ Enterprise Observability Platform

### Air-Gapped Elasticsearch + Kafka Observability Stack

**Filebeat → Kafka KRaft → Logstash → Elasticsearch → Kibana**

![Elastic](https://img.shields.io/badge/Elastic-9.3.3-005571?logo=elastic)
![Kafka](https://img.shields.io/badge/Kafka-KRaft-231F20?logo=apachekafka)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![Air-Gapped](https://img.shields.io/badge/Deployment-Air--Gapped-success)

A sanitized, production-oriented reference implementation for operating a secure log-ingestion platform in restricted environments, with durable Kafka transport, Elasticsearch lifecycle management, isolated pipeline configuration, and a portable Kibana dashboard.

</div>

---

## 🧭 Architecture at a Glance

```text
📦 Application Logs
        │
        ▼
┌────────────────┐
│ 🛰️ Filebeat    │  filestream + NDJSON + registry
└───────┬────────┘
        │ SASL/PLAIN
        ▼
┌────────────────┐
│ 📨 Kafka KRaft │  3 controllers + 3 brokers
└───────┬────────┘
        │ consumer group
        ▼
┌────────────────┐
│ 🚚 Logstash    │  isolated pipelines
└───────┬────────┘
        │ HTTPS/TLS
        ▼
┌────────────────┐
│ 🔎 Elasticsearch│  3 nodes + security + ILM
└───────┬────────┘
        ▼
┌────────────────┐
│ 📊 Kibana       │  Saved Objects dashboard
└────────────────┘
```

---

## 🧩 Implementation at a Glance

| Component | Implemented design |
|---|---|
| Filebeat | `9.3.3`, filestream, NDJSON, persistent registry |
| Kafka | KRaft, 3 controllers + 3 brokers, SASL/PLAIN, ACLs |
| Logstash | `9.3.3`, isolated Kafka → Elasticsearch pipelines |
| Elasticsearch | `9.3.3`, 3 combined-role nodes, HTTP + transport TLS |
| Kibana | `9.3.3`, portable Saved Objects dashboard |
| Deployment | Docker Compose, host-oriented distributed layout |
| Runtime model | Air-gapped / offline-capable |

---

## 🧠 Engineering Decisions

The repository is intentionally built around practical operational decisions rather than technology accumulation.

```text
Problem
  ↓
Observe / isolate failure boundary
  ↓
Choose the smallest reliable mechanism
  ↓
Verify independently
  ↓
Document the operational lesson
```

Key examples:

- **Kafka KRaft:** remove ZooKeeper from the Kafka architecture and keep controller metadata responsibility inside Kafka.
- **Kafka ACLs:** separate application, producer, consumer, management, and node identities instead of using one administrative credential everywhere.
- **Filebeat input isolation:** keep source-specific paths, parsers, and processors local to each input.
- **Persistent Filebeat registry:** preserve file identity and read position across container recreation.
- **Logstash pipeline isolation:** make configuration changes and troubleshooting local to a pipeline.
- **Elasticsearch rollover alias:** keep Logstash independent from physical backing-index names.
- **Elasticsearch ILM:** let Elasticsearch own lifecycle transitions rather than coupling retention logic to Logstash.
- **TLS boundaries:** protect Elasticsearch HTTP and transport traffic; Kafka `SASL_PLAINTEXT` is documented as authentication only.

---

## 🧯 Operational Failure Boundaries

```text
Application → Filebeat
   │             └─ file exists / readable / harvested?
   ▼
Filebeat → Kafka
   │             └─ authentication / ACL / topic?
   ▼
Kafka → Logstash
   │             └─ consumer group / partitions / offsets?
   ▼
Logstash → Elasticsearch
   │             └─ HTTPS / CA / credentials / alias?
   ▼
Elasticsearch → Kibana
                 └─ Data View / fields / dashboard?
```

This boundary-oriented troubleshooting model is one of the main operational lessons represented by the project.

---

## 🔐 Security Model

### Kafka

Dedicated principals authenticate through SASL/PLAIN and are authorized through ACLs. `SASL_PLAINTEXT` does **not** provide encryption.

### Elasticsearch

Security is enabled, with TLS for HTTP and node-to-node transport. Node-specific certificates are generated separately.

### Secrets

Production passwords, private keys, tokens, real addresses, and environment-specific identifiers remain outside Git.

---

## 🔄 Elasticsearch Lifecycle

```text
Stable write alias
       │
       ▼
 demo-logs-000001
       │
   size OR age
       ▼
    rollover
       │
       ▼
 demo-logs-000002
       │
       ▼
     warm
       │
       ▼
    delete
```

Current policy: rollover at `10 GB` primary-shard size or `1 day`, warm after `1 day`, delete after `30 days`.

---

## 📁 Repository Layout

```text
certificates/   TLS generation workflow
docs/           architecture and operations
elasticsearch/  cluster + ILM + templates
filebeat/       edge collection
kafka/          KRaft + ACLs + topics
kibana/         deployment + Saved Objects
logstash/       isolated pipelines
offline/        offline preparation
scripts/        validation utilities
ui/             optional Kafka management UI
env/            sanitized environment examples
```

---

## 🚀 Deployment Sequence

1. Stage Docker packages and images for the restricted environment.
2. Generate and distribute Elasticsearch certificates.
3. Start the three Kafka controllers.
4. Start the three Kafka brokers.
5. Create topics and apply ACLs.
6. Start the Elasticsearch nodes.
7. Apply ILM/template configuration and bootstrap the rollover alias.
8. Start Filebeat and verify publication to Kafka.
9. Start Logstash and verify consumption/indexing.
10. Start Kibana and import Saved Objects.
11. Run configuration and Saved Object validation.

---

## 🔎 Verification Strategy

Validate configuration first, then test each boundary independently:

```text
❶ Filebeat reads the expected files
❷ Kafka accepts authenticated producer traffic
❸ Kafka consumer group receives events
❹ Logstash indexes through the stable alias
❺ Elasticsearch reports healthy lifecycle state
❻ Kibana Data View and dashboard query the events
```

---

## 🎯 Interview Focus

This project is intentionally explainable end-to-end. An interview discussion can move from architecture into concrete operational questions:

- Why KRaft instead of ZooKeeper?
- How do SASL authentication and ACL authorization differ?
- Why is `SASL_PLAINTEXT` not encryption?
- Why persist the Filebeat registry?
- What happens when a rotated log file becomes unreadable?
- Why isolate Logstash pipelines?
- Why does Logstash write to an alias instead of `index-*` directly?
- What makes an Elasticsearch rollover happen?
- How do you diagnose an apparently healthy pipeline with no documents?
- What changes when the environment is air-gapped?

The documentation is designed so these questions can be answered from the actual implementation rather than from generic platform claims.

---

## 🔒 Portfolio Safety

All public examples are sanitized. Addresses, usernames, passwords, topics, aliases, registry names, host paths, and other environment-specific identifiers are fictional or represented by placeholders.

---

<div align="center">

### 🛰️ Filebeat → 📨 Kafka → 🚚 Logstash → 🔎 Elasticsearch → 📊 Kibana

**Secure. Decoupled. Observable. Operationally explainable.**

</div>
