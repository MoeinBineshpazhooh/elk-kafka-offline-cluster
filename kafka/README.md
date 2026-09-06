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
                         │  👑 Controller 01 :9093     │
                         │  👑 Controller 02 :9093     │
                         │  👑 Controller 03 :9093     │
                         └──────────────┬───────────────┘
                                        │ metadata
                 ┌──────────────────────┼──────────────────────┐
                 ▼                      ▼                      ▼
          ┌────────────┐         ┌────────────┐         ┌────────────┐
          │ 🟦 Broker 01│         │ 🟦 Broker 02│         │ 🟦 Broker 03│
          │ :9092      │         │ :9092      │         │ :9092      │
          └─────┬──────┘         └─────┬──────┘         └─────┬──────┘
                └──────────────────────┼──────────────────────┘
                                       ▼
                                  📨 Demo Topics
                                       │
                 ┌─────────────────────┼─────────────────────┐
                 ▼                     ▼                     ▼
             🛰️ Filebeat          📡 Collector            🖥️ Apps
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

> **Design goal:** Kafka is the resilient transport boundary between producers and downstream processing. KRaft removes ZooKeeper, while the three-controller quorum provides metadata-plane fault tolerance.

---

## 🧩 Node Layout

| Role | Node ID | Address | Port | Identity |
|---|---:|---|---:|---|
| 👑 Controller 01 | 1 | `<CONTROLLER_01_HOST>` | 9093 | `controller01` |
| 👑 Controller 02 | 2 | `<CONTROLLER_02_HOST>` | 9093 | `controller02` |
| 👑 Controller 03 | 3 | `<CONTROLLER_03_HOST>` | 9093 | `controller03` |
| 🟦 Broker 01 | 4 | `<BROKER_01_HOST>` | 9092 | `broker01` |
| 🟦 Broker 02 | 5 | `<BROKER_02_HOST>` | 9092 | `broker02` |
| 🟦 Broker 03 | 6 | `<BROKER_03_HOST>` | 9092 | `broker03` |

All addresses are placeholders and must be supplied locally.

---

## 🔐 Security Model

```text
Client / Node
     │
     │ SASL/PLAIN
     ▼
Kafka Authentication
     │ authenticated principal
     ▼
StandardAuthorizer
     │
 ┌───┴───┐
 ▼       ▼
ALLOW   DENY
```

Authentication and authorization are deliberately separate.

### 👥 Principals

```text
🔑 kafka-admin
🟦 broker01 / broker02 / broker03
👑 controller01 / controller02 / controller03
🛰️ filebeat
🚚 logstash
📡 collector
🖥️ akhq
📦 app
```

> `SASL_PLAINTEXT` authenticates clients but does **not** encrypt traffic. TLS-enabled Kafka listeners are required when Kafka transport confidentiality is needed.

---

## 🛡️ Least-Privilege Access

| Principal | Resource | Access |
|---|---|---|
| `filebeat` | `demo-application-logs` | `WRITE`, `DESCRIBE` |
| `logstash` | `demo-application-logs` | `READ`, `DESCRIBE` + consumer group |
| `collector` | `demo-platform-events` | `WRITE`, `DESCRIBE` |
| `akhq` | demo topics | `READ`, `DESCRIBE` |
| `app` | `demo-application-logs` | `WRITE`, `DESCRIBE` |
| `kafka-admin` | cluster | administrative access |

Application identities are not cluster super-users.

---

## 🧠 Engineering Decisions

| Decision | Why |
|---|---|
| KRaft | Remove ZooKeeper and simplify Kafka metadata management |
| 3 controllers | Maintain a practical metadata quorum |
| 3 brokers | Replication and broker-level fault tolerance |
| SASL/PLAIN | Explicit client authentication matching the implementation |
| ACLs | Least-privilege producer/consumer access |
| RF=3 / min ISR=2 | Maintain availability while requiring replicated writes |
| Explicit topics | Prevent accidental topic creation |
| Separate node identities | Avoid using application credentials for cluster operations |
| Air-gapped deployment | Runtime hosts do not depend on public internet access |

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
├── security/
│   ├── access-matrix.yaml
│   ├── admin-client.properties.example
│   └── apply-acls.sh
├── docker-compose.broker01.yml
├── docker-compose.broker02.yml
├── docker-compose.broker03.yml
├── docker-compose.controller01.yml
├── docker-compose.controller02.yml
├── docker-compose.controller03.yml
└── topics/
    ├── topics.yml
    └── create-topics.sh
```

---

## 🚀 Deployment

### 1. Generate one Cluster UUID

```bash
docker run --rm apache/kafka:latest \
  bash -lc "/opt/kafka/bin/kafka-storage.sh random-uuid"
```

Store the generated value only in the local Kafka environment configuration.

### 2. Start controllers

Prepare local controller storage and start the three controller Compose files on their respective hosts.

### 3. Start brokers

Prepare local broker storage and start the three broker Compose files on their respective hosts.

### 4. Create demo topics

Use `topics/create-topics.sh` after broker health is confirmed. Supply the local bootstrap addresses through the environment rather than committing them.

### 5. Apply ACLs

Create the local admin client configuration from `security/admin-client.properties.example`, then run `security/apply-acls.sh`.

---

## 🔎 Verification

### Controller quorum

```bash
docker exec kafka-controller01 bash -lc \
  "/opt/kafka/bin/kafka-metadata-quorum.sh \
   --bootstrap-controller <CONTROLLER_01_HOST>:9093 describe --status"
```

### Broker API

```bash
docker exec kafka-broker01 bash -lc \
  "/opt/kafka/bin/kafka-broker-api-versions.sh \
   --bootstrap-server <BROKER_01_HOST>:9092 \
   --command-config /path/to/admin-client.properties"
```

### ACLs

```bash
docker exec kafka-broker01 bash -lc \
  "/opt/kafka/bin/kafka-acls.sh \
   --bootstrap-server <BROKER_01_HOST>:9092 \
   --command-config /path/to/admin-client.properties \
   --list"
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

These settings provide a practical replicated durability posture for the three-broker event backbone.

---

## 🧪 Practical Failure Story

When Kafka appears reachable but clients cannot publish or consume, troubleshoot in this order:

```text
Controller quorum
      ↓
Broker registration
      ↓
Listener reachability
      ↓
SASL authentication
      ↓
ACL authorization
      ↓
Topic existence / configuration
      ↓
Partition assignment / consumer group
      ↓
ISR / replication health
```

This ordering prevents authentication problems from being confused with ACL, networking, or replication problems.

---

## 🧰 Troubleshooting Checklist

```text
❶ Controller quorum healthy?
        ↓
❷ Broker registered in KRaft metadata?
        ↓
❸ Listener / advertised listener reachable?
        ↓
❹ SASL credentials valid?
        ↓
❺ ACL grants the operation?
        ↓
❻ Topic exists?
        ↓
❼ Consumer group assigned partitions?
        ↓
❽ ISR count >= min.insync.replicas?
```

---

## 🗝️ Credential Rule

```text
Git repository
      │
 ┌────┴────┐
 ▼         ▼
SAFE     NEVER
 │         │
examples  passwords
placeholders private keys
documentation tokens
```

Real credentials belong in local ignored configuration only.

---

## 🔒 Portfolio Safety

All public addresses are masked, topics and environment identifiers are fictional, and credentials are placeholders. No production secrets or infrastructure identifiers belong in Git.

---

<div align="center">

### ⚡ Kafka → 🚚 Logstash → 🔎 Elasticsearch → 📊 Kibana

**Authenticated. Replicated. Decoupled. Operationally explainable.**

</div>
