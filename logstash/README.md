<div align="center">

# 🚚 Logstash Pipeline Layer

### Kafka → Logstash → Elasticsearch

![Logstash](https://img.shields.io/badge/Logstash-9.3.3-005571?logo=logstash)
![Kafka](https://img.shields.io/badge/Kafka-SASL%2FPLAIN-231F20?logo=apachekafka)
![Elasticsearch](https://img.shields.io/badge/Elasticsearch-HTTPS-005571?logo=elasticsearch)
![Deployment](https://img.shields.io/badge/Deployment-Docker%20Compose-orange)

</div>

---

## 🧭 Architecture at a Glance

```text
📨 Kafka KRaft
      │
      │ authenticated consume
      ▼
┌─────────────────────────────┐
│ 🚚 Logstash                 │
│                             │
│ isolated pipeline configs   │
│ shared consumer group       │
└──────────────┬──────────────┘
               │ HTTPS + CA
               ▼
┌─────────────────────────────┐
│ 🔎 Elasticsearch            │
│                             │
│ stable write alias + ILM    │
└─────────────────────────────┘
```

---

## 🧩 Implementation at a Glance

| Capability | Implementation |
|---|---|
| Version | `9.3.3` |
| Input | Kafka |
| Authentication | SASL/PLAIN |
| Event format | JSON |
| Pipeline model | Explicit `pipelines.yml` |
| Configuration | Isolated `.conf` files |
| Instances | 2 Logstash hosts in the example topology |
| Scaling model | Shared Kafka consumer group |
| Elasticsearch transport | HTTPS + CA validation |
| Index target | Stable rollover alias |
| Lifecycle owner | Elasticsearch ILM |
| Deployment | Docker Compose |
| Runtime | Air-gapped / offline-capable |

---

## 🧠 Responsibility Boundary

Logstash owns **transport between Kafka and Elasticsearch plus pipeline-level event processing**.

```text
Kafka
  │
  ▼
🚚 Logstash
  │
  ├── consume
  ├── authenticate
  ├── decode JSON
  ├── apply pipeline processing
  └── write to stable alias
              │
              ▼
       🔎 Elasticsearch
```

Elasticsearch owns physical index generations and lifecycle. Logstash therefore does not need to construct daily index names or manage rollover state.

---

## 🔐 Security Model

### Kafka

```text
Logstash
   │ username + password
   │ SASL/PLAIN
   ▼
Kafka listener
   │
   ▼
ACL authorization
```

`SASL_PLAINTEXT` authenticates the client but does not encrypt traffic. Use a TLS-enabled Kafka listener when confidentiality is required.

### Elasticsearch

```text
Logstash
   │
   │ HTTPS + CA validation
   ▼
Elasticsearch HTTP API
```

Credentials and certificate material are supplied through the local deployment environment.

---

## 🧱 Pipeline Isolation

```text
logstash/config/pipelines.yml
              │
       ┌──────┴──────┐
       ▼             ▼
 pipeline A       pipeline B
    .conf            .conf
       │             │
       └──────┬──────┘
              ▼
          Logstash
```

The current Kafka → Elasticsearch path is explicitly registered in `pipelines.yml`. A new logical data path can be introduced as a separate pipeline rather than expanding one monolithic configuration.

### Why isolate pipelines?

- configuration ownership stays clear;
- troubleshooting is localized;
- unrelated changes have a smaller blast radius;
- each pipeline can be mounted explicitly.

---

## 📁 Repository Layout

```text
logstash/
├── README.md
├── config/
│   ├── logstash.yml
│   └── pipelines.yml
├── pipeline/
│   ├── demo-kafka-to-elasticsearch.conf
│   └── kafka-to-elasticsearch.conf
├── docker-compose.logstash01.yml
└── docker-compose.logstash02.yml
```

Environment-specific credentials and endpoints live in `env/logstash.env` locally and are represented publicly by `env/logstash.env.example`.

---

## ⚙️ Current Pipeline

```text
Kafka topic
    │
    ▼
Kafka input
    │
    ▼
JSON codec
    │
    ▼
Small metadata enrichment
    │
    ▼
Elasticsearch output
    │
    ▼
demo-logs alias
```

The Elasticsearch output uses the stable rollover alias. ILM remains an Elasticsearch concern.

---

## 🚀 Deployment

### 1. Prepare local environment values

```bash
cp env/logstash.env.example env/logstash.env
```

Replace placeholders locally and keep the resulting file outside Git.

### 2. Start Logstash instances

```bash
docker compose -f docker-compose.logstash01.yml up -d
docker compose -f docker-compose.logstash02.yml up -d
```

The instances use the same Kafka consumer group so Kafka can distribute partitions between them.

---

## 🔎 Verification

Check the Logstash monitoring API:

```bash
curl http://127.0.0.1:9600/_node/pipelines?pretty
```

Inspect loaded pipeline configuration:

```bash
docker exec logstash01 ls -l /usr/share/logstash/pipeline/
```

Check Kafka-related failures:

```bash
docker logs logstash01 2>&1 | grep -Ei 'sasl|authentication|kafka'
```

Check Elasticsearch/TLS failures:

```bash
docker logs logstash01 2>&1 | grep -Ei 'elasticsearch|ssl|certificate'
```

---

## 🧯 Troubleshooting Flow

```text
No documents?
      │
      ▼
Pipeline loaded?
      │
      ▼
Kafka authentication?
      │
      ▼
Topic / consumer group receiving?
      │
      ▼
Elasticsearch HTTPS reachable?
      │
      ▼
CA / credentials valid?
      │
      ▼
Alias exists and is writable?
      │
      ▼
ILM progressing?
```

The order intentionally moves from pipeline loading to transport, authentication, consumption, storage, and lifecycle.

---

## 🧠 Operational Decisions

| Decision | Why |
|---|---|
| Isolated pipelines | Reduce configuration blast radius |
| Explicit `pipelines.yml` | Make active pipelines obvious |
| Shared consumer group | Distribute Kafka partitions across Logstash instances |
| SASL/PLAIN | Match the implemented Kafka authentication model |
| HTTPS to Elasticsearch | Protect Logstash → Elasticsearch traffic |
| Stable alias | Hide physical backing-index names |
| ES-side ILM | Keep lifecycle ownership with Elasticsearch |
| Compose per host | Match distributed air-gapped deployment |

---

## 🧪 Practical Failure Story

When Logstash appears healthy but Elasticsearch contains no new documents, do not immediately change the output configuration.

```text
Logstash running
      │
      ├── Is the pipeline loaded?
      ├── Is Kafka authentication successful?
      ├── Are partitions assigned to the group?
      ├── Are offsets advancing?
      ├── Is Elasticsearch reachable over HTTPS?
      ├── Is the alias valid?
      └── Is ILM state healthy?
```

This separates a consumer problem from an Elasticsearch indexing or lifecycle problem.

---

## 🔒 Portfolio Safety

Public examples use fictional topics, aliases, addresses, usernames, and placeholders. No production credentials, private keys, registry names, or environment-specific identifiers belong in Git.

---

<div align="center">

### 📨 Kafka → 🚚 Logstash → 🔎 Elasticsearch

**Isolated. Authenticated. Predictable. Operationally explainable.**

</div>
