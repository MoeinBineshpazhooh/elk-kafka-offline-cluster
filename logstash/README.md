# Logstash — Isolated Pipelines

<div align="center">

## Kafka → Logstash → Elasticsearch

**Authenticated ingestion · isolated pipeline configuration · TLS-protected Elasticsearch output**

![Logstash](https://img.shields.io/badge/Logstash-9.2.4-005571?style=for-the-badge&logo=logstash)
![Kafka](https://img.shields.io/badge/Kafka-SASL%2FPLAIN-231F20?style=for-the-badge&logo=apachekafka)
![Elasticsearch](https://img.shields.io/badge/Elasticsearch-HTTPS-005571?style=for-the-badge&logo=elasticsearch)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker)

</div>

---

## 🧭 Architecture

This implementation deliberately keeps **each Logstash pipeline as an isolated configuration unit**. Pipeline definitions live independently and are mounted explicitly into the container by Docker Compose.

```text
                         ┌──────────────────────┐
                         │   Kafka Cluster      │
                         │  3 Broker Example    │
                         │                      │
                         │ SASL/PLAIN           │
                         └──────────┬───────────┘
                                    │
                                    │ authenticated consume
                                    ▼
              ┌─────────────────────────────────────────┐
              │              Logstash Tier              │
              │                                         │
              │  ┌───────────────────────────────────┐  │
              │  │ demo-kafka-to-elasticsearch       │  │
              │  │ isolated pipeline configuration    │  │
              │  └───────────────────────────────────┘  │
              │                                         │
              │       logstash01  ⇄  logstash02         │
              │       shared consumer group             │
              └──────────────────┬──────────────────────┘
                                 │
                                 │ HTTPS + CA validation
                                 ▼
                    ┌──────────────────────────┐
                    │    Elasticsearch Cluster │
                    │                          │
                    │  demo-logs write alias   │
                    │  + ILM rollover          │
                    └──────────────────────────┘
```

---

## 🔐 Security Model

### Kafka authentication

The Kafka input uses **SASL/PLAIN** authentication:

```text
Logstash
   │
   │ username + password
   │ SASL/PLAIN
   ▼
Kafka Broker Listener
```

The credentials are supplied through the environment file and are **not embedded in the pipeline configuration**.

> `SASL_PLAINTEXT` provides authentication but does not encrypt Kafka traffic. Use `SASL_SSL` when transport confidentiality is required by the deployment.

### Elasticsearch transport

The Elasticsearch output connects over HTTPS and validates the server certificate against the mounted CA:

```text
Logstash
   │
   │ HTTPS
   │ CA validation
   ▼
Elasticsearch
```

---

## 🧱 Pipeline Isolation

The central design principle is simple:

```text
logstash/config/pipelines.yml
              │
              ├───────────────┐
              │               │
              ▼               ▼
     pipeline A.conf      pipeline B.conf
              │               │
              ▼               ▼
       dedicated mount    dedicated mount
```

The current enabled pipeline is:

```text
pipeline.id: demo-kafka-to-elasticsearch
path.config: /usr/share/logstash/pipeline/demo-kafka-to-elasticsearch.conf
```

Adding another data path does not require merging unrelated logic into one large configuration. Create a separate `.conf`, add its own `pipeline.id`, and explicitly mount it.

---

## 📦 Repository Layout

```text
logstash/
├── config/
│   ├── logstash.yml
│   └── pipelines.yml
│
├── pipeline/
│   ├── demo-kafka-to-elasticsearch.conf
│   └── beats-to-kafka.conf
│
├── docker-compose.logstash01.yml
├── docker-compose.logstash02.yml
└── README.md
```

Environment-specific values are kept outside the pipeline files:

```text
env/logstash.env.example
        │
        └── copied locally to env/logstash.env
```

---

## ⚙️ Current Pipeline

### Input — Kafka

The pipeline consumes JSON events from the Kafka cluster using:

- configurable bootstrap servers
- configurable topic list
- shared consumer group
- configurable consumer threads
- SASL/PLAIN authentication
- JSON codec

### Filter

A small metadata marker identifies Kafka as the event source:

```text
[@metadata][source] = kafka
```

### Output — Elasticsearch

Events are written to the stable rollover alias:

```text
demo-logs
```

The Elasticsearch output uses:

- username/password authentication
- HTTPS
- mounted CA certificate
- configurable certificate verification mode
- rollover alias instead of a daily index name

This keeps Logstash independent from the physical backing-index names created by ILM.

---

## 🚀 Deployment

### 1. Prepare environment values

```bash
cp env/logstash.env.example env/logstash.env
```

Set the local Kafka and Elasticsearch credentials in the ignored environment file.

### 2. Start Logstash 01

```bash
cd logstash
docker compose -f docker-compose.logstash01.yml up -d
docker logs -f logstash01
```

### 3. Start Logstash 02

```bash
docker compose -f docker-compose.logstash02.yml up -d
docker logs -f logstash02
```

Both instances use the same consumer group, allowing Kafka to distribute partitions between them.

---

## 🔎 Verification

Check the Logstash monitoring API:

```bash
curl http://127.0.0.1:9600/_node/pipelines?pretty
```

The expected pipeline should include:

```text
demo-kafka-to-elasticsearch
```

Check the container configuration:

```bash
docker exec logstash01 ls -l /usr/share/logstash/pipeline/
```

Verify Kafka authentication failures in logs:

```bash
docker logs logstash01 2>&1 | grep -Ei 'sasl|authentication|kafka'
```

Verify Elasticsearch connectivity:

```bash
docker logs logstash01 2>&1 | grep -Ei 'elasticsearch|ssl|certificate'
```

---

## 🛠️ Troubleshooting Flow

```text
                    Logstash not ingesting?
                              │
                              ▼
                    Pipeline loaded by LS?
                         │          │
                        NO         YES
                         │          │
                         ▼          ▼
                 Check pipelines.yml   Kafka auth?
                                      │      │
                                     NO     YES
                                      │      │
                                      ▼      ▼
                               Check SASL env   Kafka topic/group
                                             │
                                             ▼
                                      Elasticsearch output?
                                             │
                                             ▼
                                       HTTPS / CA valid?
                                             │
                                             ▼
                                      Alias + ILM healthy?
```

For ILM-specific problems, see the Elasticsearch lifecycle documentation in the repository.

---

## 🧠 Operational Decisions

| Decision | Implementation |
|---|---|
| Pipeline isolation | Separate `.conf` per logical data path |
| Pipeline registration | Explicit `pipelines.yml` entries |
| Container mounting | Explicit read-only configuration mounts |
| Kafka authentication | SASL/PLAIN |
| Kafka consumer scaling | Shared consumer group across Logstash nodes |
| Elasticsearch security | HTTPS + CA validation |
| Index target | Stable rollover alias |
| Configuration secrets | Environment file, excluded from Git |
| Deployment model | Separate Compose file per Logstash host |

---

## 🔒 Portfolio Safety

All infrastructure values in this repository are intentionally fictional:

- documentation-only IP addresses
- fictional topic names
- fictional aliases
- placeholder credentials
- no production registry names
- no production usernames or passwords

The repository demonstrates the architecture without exposing environment-specific data.

---

<div align="center">

### Kafka authentication → isolated Logstash pipelines → HTTPS Elasticsearch → ILM-managed storage

**Small configuration units. Clear ownership. Predictable operations.**

</div>
