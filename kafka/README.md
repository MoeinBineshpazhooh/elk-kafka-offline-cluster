<div align="center">

# 🛰️ Kafka Event Streaming Backbone

### KRaft • 3 Controllers • 3 Brokers • SASL/PLAIN • ACLs

![Kafka](https://img.shields.io/badge/Apache%20Kafka-KRaft-black?logo=apachekafka)
![Security](https://img.shields.io/badge/Security-SASL%2FPLAIN%20%2B%20ACLs-blue?logo=apachekafka)
![Topology](https://img.shields.io/badge/Topology-3%20%2B%203-success)
![Deployment](https://img.shields.io/badge/Deployment-Air--gapped-orange)

</div>

---

## 🧭 Architecture at a Glance

```text
                         ┌──────────────────────────────┐
                         │       🧠 KRaft Quorum        │
                         │                              │
                         │  👑 Controller 01  :9093    │
                         │  👑 Controller 02  :9093    │
                         │  👑 Controller 03  :9093    │
                         └──────────────┬───────────────┘
                                        │ metadata
                 ┌──────────────────────┼──────────────────────┐
                 │                      │                      │
          ┌──────▼──────┐        ┌──────▼──────┐        ┌──────▼──────┐
          │ 🟦 Broker 01 │        │ 🟦 Broker 02 │        │ 🟦 Broker 03 │
          │ :9092        │        │ :9092        │        │ :9092        │
          └──────┬───────┘        └──────┬───────┘        └──────┬───────┘
                 └──────────────────────┬───────────────────────┘
                                        │
             ┌──────────────────────────┼──────────────────────────┐
             │                          │                          │
        📥 Filebeat                📥 Collector                🖥️ Apps
             │                          │                          │
             └──────────────────────────┼──────────────────────────┘
                                        ▼
                              📨 Demo Topics
                                        │
                                        ▼
                                  🚚 Logstash
                                        │
                                        ▼
                              🔎 Elasticsearch
                                        │
                                        ▼
                                   📊 Kibana
```

> **Design goal:** Kafka is the resilient event-streaming backbone between producers and the ELK ingestion layer. KRaft removes ZooKeeper and the 3-controller quorum provides metadata-plane fault tolerance.

---

## 🧩 Node Layout

| Role | Node ID | Documentation address | Port | Identity |
|---|---:|---|---:|---|
| 👑 Controller 01 | 1 | `192.0.2.11` | 9093 | `controller01` |
| 👑 Controller 02 | 2 | `192.0.2.12` | 9093 | `controller02` |
| 👑 Controller 03 | 3 | `192.0.2.13` | 9093 | `controller03` |
| 🟦 Broker 01 | 4 | `192.0.2.21` | 9092 | `broker01` |
| 🟦 Broker 02 | 5 | `192.0.2.22` | 9092 | `broker02` |
| 🟦 Broker 03 | 6 | `192.0.2.23` | 9092 | `broker03` |

> Addresses above use RFC 5737 documentation space. Replace them in a real deployment.

---

## 🔐 Security Model

Authentication and authorization are deliberately separated:

```text
             ┌───────────────────────┐
             │ Client / Node         │
             └──────────┬────────────┘
                        │ SASL/PLAIN
                        ▼
             ┌───────────────────────┐
             │ Kafka Authentication  │
             └──────────┬────────────┘
                        │ authenticated principal
                        ▼
             ┌───────────────────────┐
             │ StandardAuthorizer    │
             │ ACL evaluation        │
             └──────────┬────────────┘
                        │
                ┌───────┴───────┐
                ▼               ▼
              ALLOW             DENY
```

### 👥 Principals

```text
🔑 kafka-admin
🟦 broker01 / broker02 / broker03
👑 controller01 / controller02 / controller03
📥 filebeat
🚚 logstash
📡 collector
🖥️ akhq
📦 app
```

**Important:** passwords in this repository are placeholders only. Real passwords belong in local ignored environment/secret files.

See [`security/access-matrix.yaml`](security/access-matrix.yaml) for the sanitized identity and ACL reference.

---

## 🛡️ Least-Privilege Access

| Principal | Resource | Access |
|---|---|---|
| `filebeat` | `demo-application-logs` | `WRITE`, `DESCRIBE` |
| `logstash` | `demo-application-logs` | `READ`, `DESCRIBE` |
| `collector` | `demo-platform-events` | `WRITE`, `DESCRIBE` |
| `akhq` | demo topics | `READ`, `DESCRIBE` |
| `app` | `demo-application-logs` | `WRITE`, `DESCRIBE` |
| `kafka-admin` | cluster | administrative access |

The application identities are **not** cluster super-users. Internal Kafka node identities are explicitly separated from application identities.

---

## 📁 Repository Layout

```text
kafka/
├── README.md
├── config/
│   ├── broker1.properties
│   ├── broker2.properties
│   ├── broker3.properties
│   ├── controller1.properties
│   ├── controller2.properties
│   ├── controller3.properties
│   └── controller-security.properties
│
├── security/
│   ├── access-matrix.yaml
│   └── admin-client.properties.example
│
├── docker-compose.broker01.yml
├── docker-compose.broker02.yml
├── docker-compose.broker03.yml
├── docker-compose.controller01.yml
├── docker-compose.controller02.yml
├── docker-compose.controller03.yml
│
└── topics/
    └── create-topics.sh
```

---

## 🚀 Deployment

### 1. Generate one Cluster UUID

```bash
docker run --rm apache/kafka:latest \
  bash -lc "/opt/kafka/bin/kafka-storage.sh random-uuid"
```

Set the generated value in the local, ignored Kafka environment files.

### 2. Prepare controller storage

Run on each controller host:

```bash
sudo mkdir -p /opt/kafka/controller/data
```

Start the three controllers:

```bash
docker compose -f docker-compose.controller01.yml up -d
docker compose -f docker-compose.controller02.yml up -d
docker compose -f docker-compose.controller03.yml up -d
```

### 3. Prepare broker storage

Run on each broker host:

```bash
sudo mkdir -p /opt/kafka/broker/data
```

Start the three brokers:

```bash
docker compose -f docker-compose.broker01.yml up -d
docker compose -f docker-compose.broker02.yml up -d
docker compose -f docker-compose.broker03.yml up -d
```

> Each host uses its own compose file. This matches the distributed, host-networked deployment model.

---

## 🔎 Verification

### Controller quorum

```bash
docker exec kafka-controller01 bash -lc \
  "/opt/kafka/bin/kafka-metadata-quorum.sh \
   --bootstrap-controller 192.0.2.11:9093 describe --status"
```

### Broker API connectivity

Use a local SASL client configuration such as [`security/admin-client.properties.example`](security/admin-client.properties.example):

```bash
docker exec kafka-broker01 bash -lc \
  "/opt/kafka/bin/kafka-broker-api-versions.sh \
   --bootstrap-server 192.0.2.21:9092 \
   --command-config /path/to/admin-client.properties"
```

### Topics

```bash
cd kafka/topics
BOOTSTRAP_SERVERS="192.0.2.21:9092,192.0.2.22:9092,192.0.2.23:9092" \
  ./create-topics.sh
```

---

## 🧱 Durability Defaults

```text
Partitions per topic              = 3
Default replication factor       = 3
Minimum in-sync replicas         = 2
Offsets topic replication        = 3
Transaction state replication    = 3
Transaction state minimum ISR    = 2
```

This gives the 3-broker cluster a practical **N=3 / quorum-style durability posture** for the event-streaming backbone.

---

## 🧪 SASL Client Examples

Every client should authenticate with its **own** principal:

```properties
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="CLIENT_USER" password="CHANGE_ME_CLIENT_PASSWORD";
```

Examples:

```text
Filebeat  → username=filebeat
Logstash  → username=logstash
Collector → username=collector
AKHQ      → username=akhq
Apps      → username=app
Admin     → username=kafka-admin
```

Never reuse the broker/controller password for an application.

---

## 🗝️ Credential Rule

```text
                 Git repository
                       │
             ┌─────────┴─────────┐
             │                   │
       SAFE TO COMMIT       NEVER COMMIT
             │                   │
             ▼                   ▼
       usernames           real passwords
       placeholders        private keys
       examples            production certs
       documentation       tokens/secrets
```

The repository intentionally contains `CHANGE_ME_*` placeholders rather than infrastructure credentials.

---

## 🧰 Troubleshooting Checklist

```text
❶ Controller quorum healthy?
        ↓
❷ Broker registered in KRaft metadata?
        ↓
❸ SASL credentials valid?
        ↓
❹ Listener / advertised listener reachable?
        ↓
❺ ACL grants the requested operation?
        ↓
❻ Topic exists with expected replication?
        ↓
❼ ISR count >= min.insync.replicas?
```

This ordering separates quorum, networking, authentication, authorization, topic configuration, and replication failure domains.

---

<div align="center">

### ⚡ Kafka → 🚚 Logstash → 🔎 Elasticsearch → 📊 Kibana

**Secure. Decoupled. Fault-tolerant. Air-gapped ready.**

</div>
