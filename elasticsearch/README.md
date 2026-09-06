<div align="center">

# 🔎 Elasticsearch Storage & Lifecycle Layer

### 3 Nodes • TLS • Security • ILM • Rollover • Persistent Storage

![Elasticsearch](https://img.shields.io/badge/Elasticsearch-9.3.3-005571?logo=elasticsearch)
![Security](https://img.shields.io/badge/Security-TLS%20%2B%20Security-blue)
![Lifecycle](https://img.shields.io/badge/Lifecycle-ILM%20%2B%20Rollover-success)
![Deployment](https://img.shields.io/badge/Deployment-Docker%20Compose-orange)

</div>

---

## 🧭 Architecture at a Glance

```text
Filebeat → Kafka → Logstash
                      │
                      │ HTTPS + CA validation
                      ▼
        ┌──────────────────────────────┐
        │   🔎 Elasticsearch Cluster   │
        │                              │
        │  ES01   ES02   ES03          │
        │  master + data + ingest      │
        │                              │
        │  🔐 HTTP TLS                 │
        │  🔐 Transport TLS            │
        │  🔄 ILM + rollover           │
        └──────────────┬───────────────┘
                       │
                       ▼
                    📊 Kibana
```

---

## 🧩 Implementation at a Glance

| Capability | Implementation |
|---|---|
| Version | `9.3.3` |
| Nodes | 3 |
| Roles | master · data · ingest |
| Client traffic | HTTPS / TLS |
| Node traffic | Transport TLS |
| Authentication | Elasticsearch security |
| Persistence | Host-mounted data |
| Lifecycle | Elasticsearch ILM |
| Rollover | Stable write alias |
| Retention | 30 days |
| Deployment | Docker Compose per host |
| Runtime | Air-gapped / offline-capable |

---

## 🧠 Responsibility Boundary

Elasticsearch owns **storage, search, lifecycle, and indexing state**.

```text
🚚 Logstash
     │
     │ write to stable alias
     ▼
🔎 Elasticsearch
     │
     ├── index template
     ├── rollover alias
     ├── ILM policy
     ├── shard allocation
     └── document storage
          │
          ▼
       📊 Kibana
```

Logstash does not need to know which numbered backing index is currently active.

---

## 🔐 Security Model

```text
Logstash / Kibana / Admin
          │
          │ HTTPS + TLS
          ▼
   Elasticsearch HTTP
          │
          ▼
     Security layer

ES01 ◄──── TLS ────► ES02
 │                    │
 └──────── TLS ──────► ES03
```

HTTP and transport TLS use node-specific certificate material. The CA is distributed only to components that need to establish trust.

---

## 📁 Repository Layout

```text
elasticsearch/
├── README.md
├── config/
│   ├── es01/elasticsearch.yml
│   ├── es02/elasticsearch.yml
│   └── es03/elasticsearch.yml
├── docker-compose.es01.yml
├── docker-compose.es02.yml
├── docker-compose.es03.yml
├── ilm/
│   ├── observability-ilm-policy.json
│   └── README.md
└── templates/
    ├── observability-index-template.json
    ├── create-rollover-index.sh
    └── README.md
```

---

## ⚙️ Configuration Model

The three nodes share the same cluster design while keeping node identity and certificate references specific to each node.

```yaml
cluster.name: portfolio-observability
node.name: es01
node.roles: [ master, data, ingest ]
xpack.security.enabled: true
xpack.monitoring.collection.enabled: true
```

The Compose deployment uses host networking and persistent host-mounted data/configuration/certificate paths.

---

## 💾 Persistence

```text
Host data directory
        │
        ▼
Elasticsearch container
        │
        ▼
Persistent index / cluster state
```

The deployment also exposes a repository path for local snapshot operations. Snapshot data itself is not committed to Git.

---

## 🔄 ILM & Rollover

```text
                 demo-logs alias
                       │
                       ▼
                demo-logs-000001
                       │
              ┌────────┴────────┐
              │                 │
           10 GB               1 day
              │                 │
              └────────┬────────┘
                       ▼
                    rollover
                       │
                       ▼
                demo-logs-000002
                       │
                       ▼
                     warm
                       │
                     30d
                       ▼
                    delete
```

| Phase | Behavior |
|---|---|
| Hot | Rollover at `10 GB` primary-shard size or `1 day` |
| Warm | Begins after `1 day`; no additional action |
| Delete | Deletes indices after `30 days` |

### Why the alias matters

```text
Logstash → demo-logs alias → current write index
                         ↘ rollover → next backing index
```

The stable alias decouples producers from physical index generations. The bootstrap operation sets `is_write_index: true` on the initial backing index; subsequent generations are managed by ILM.

---

## 🚀 Deployment

### 1. Prepare host prerequisites

```bash
sudo sysctl -w vm.max_map_count=262144
```

### 2. Generate certificates

Use the workflow under `certificates/elasticsearch/` and keep generated private material outside Git.

### 3. Prepare local environment values

```bash
cp env/elastic.env.example env/elastic.env
```

### 4. Start each node

```bash
docker compose -f docker-compose.es01.yml up -d
```

Repeat with the corresponding Compose file on the other hosts.

### 5. Apply lifecycle configuration

Apply the ILM policy and index template, then bootstrap the initial rollover index.

---

## 🔎 Verification

### Cluster health

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_cluster/health?pretty"
```

### Node membership

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_cat/nodes?v"
```

### ILM state

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/<INDEX_NAME>/_ilm/explain?pretty"
```

---

## 🧯 Troubleshooting Flow

```text
Elasticsearch issue?
        │
        ▼
Cluster health
   │         │
healthy   unhealthy
   │         │
   ▼         ▼
ILM/alias   node logs
             │
             ▼
       discovery / TLS
```

For rollover failures, check:

1. ILM policy exists.
2. Index template is applied.
3. Rollover alias is correct.
4. Exactly one backing index is the write index.
5. `_ilm/explain` shows the expected policy/phase.
6. The configured rollover condition has actually been reached.

---

## 🧠 Operational Decisions

| Decision | Why |
|---|---|
| 3 nodes | Practical cluster quorum and fault tolerance |
| Combined roles | Matches the actual deployment without unnecessary tiers |
| TLS | Protect client and node-to-node Elasticsearch traffic |
| Host persistence | Container replacement should not replace data |
| Stable alias | Hide physical index generations from Logstash |
| ES-side ILM | Keep lifecycle ownership with the storage platform |
| 30-day retention | Controlled storage growth |
| Compose per host | Fits the distributed air-gapped deployment model |

---

## 🧪 Practical Failure Story

A useful operational debugging sequence is:

```text
No documents visible
       │
       ▼
Is Logstash connected?
       │
       ▼
Is Elasticsearch reachable over HTTPS?
       │
       ▼
Does authentication succeed?
       │
       ▼
Does the alias exist?
       │
       ▼
Is a backing index the write index?
       │
       ▼
Is ILM attached and progressing?
       │
       ▼
Are documents actually indexed?
```

This separates ingestion, transport, authentication, alias, lifecycle, and indexing problems instead of treating them as one Elasticsearch failure.

---

## 🔒 Portfolio Safety

Public examples use placeholders only. No production addresses, credentials, private keys, registry names, or environment-specific identifiers belong in this repository.

---

<div align="center">

### Secure Cluster → Stable Alias → ILM Rollover → Retention

**Persistent. Secure. Searchable. Operationally explainable.**

</div>
