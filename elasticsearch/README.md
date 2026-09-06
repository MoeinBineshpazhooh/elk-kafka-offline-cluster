<div align="center">

# 🔎 Elasticsearch

### 3-Node Secure Search & Observability Cluster

**Docker Compose · TLS · Security · ILM · Snapshots · Operationally Focused**

<br>

![Elasticsearch](https://img.shields.io/badge/Elasticsearch-9.2.4-005571?style=for-the-badge&logo=elasticsearch&logoColor=white)
![Nodes](https://img.shields.io/badge/Nodes-3-00A98F?style=for-the-badge)
![TLS](https://img.shields.io/badge/TLS-Enabled-4B5563?style=for-the-badge)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![ILM](https://img.shields.io/badge/ILM-Rollover-8B5CF6?style=for-the-badge)

</div>

---

## 🧭 Architecture

```text
                         ┌─────────────────────────┐
                         │     Observability        │
                         │       Data Sources       │
                         └────────────┬────────────┘
                                      │
                                      ▼
                         ┌─────────────────────────┐
                         │       Log Pipeline      │
                         └────────────┬────────────┘
                                      │
                                      ▼
              ┌─────────────────────────────────────────────┐
              │              Elasticsearch Cluster          │
              │                                             │
              │   ┌──────────┐   ┌──────────┐   ┌──────────┐ │
              │   │  ES01    │   │  ES02    │   │  ES03    │ │
              │   │ Master   │   │ Master   │   │ Master   │ │
              │   │ Data     │   │ Data     │   │ Data     │ │
              │   │ Ingest   │   │ Ingest   │   │ Ingest   │ │
              │   └────┬─────┘   └────┬─────┘   └────┬─────┘ │
              │        │              │              │       │
              │        └──────────────┼──────────────┘       │
              │                       │                      │
              └───────────────────────┼──────────────────────┘
                                      │
                         ┌────────────┴────────────┐
                         │   TLS / HTTPS : 9200   │
                         └─────────────────────────┘
```

---

## 🎯 What This Implements

This component represents the Elasticsearch layer actually used in the platform:

- **3 Elasticsearch nodes**
- all nodes are **master-eligible + data + ingest**
- Docker Compose deployment per host
- persistent data volumes
- TLS on HTTP and transport traffic
- Elasticsearch security enabled
- snapshot repository path configured
- cluster monitoring collection enabled
- ILM-based rollover and retention

The configuration deliberately stays close to the implemented environment instead of introducing additional Elasticsearch tiers or services.

---

## 🖥️ Node Topology

| Node | Address | Roles | HTTP | Transport |
|---|---|---|---:|---:|
| `es01` | `192.0.2.31` | master · data · ingest | `9200` | `9300` |
| `es02` | `192.0.2.32` | master · data · ingest | `9200` | `9300` |
| `es03` | `192.0.2.33` | master · data · ingest | `9200` | `9300` |

> The addresses above are documentation-only examples. Replace them locally for deployment.

---

## 🔐 Security Model

```text
                         ┌──────────────────┐
                         │     Clients      │
                         └────────┬─────────┘
                                  │
                           HTTPS + TLS
                                  │
                                  ▼
                  ┌────────────────────────────┐
                  │     Elasticsearch HTTP     │
                  │         :9200              │
                  └─────────────┬──────────────┘
                                │
                       Authentication
                                │
                                ▼
                  ┌────────────────────────────┐
                  │     Elasticsearch Security │
                  └─────────────┬──────────────┘
                                │
                                ▼
                  ┌────────────────────────────┐
                  │      Cluster / Indices     │
                  └────────────────────────────┘

       Node-to-node communication
                    │
                 TLS / 9300
                    │
                    ▼
          ES01 ◄────► ES02 ◄────► ES03
```

HTTP TLS uses node-specific PKCS#12 keystores, while transport TLS provides encrypted node-to-node communication.

---

## 📁 Repository Layout

```text
elasticsearch/
├── README.md
├── config/
│   ├── es01/
│   │   └── elasticsearch.yml
│   ├── es02/
│   │   └── elasticsearch.yml
│   └── es03/
│       └── elasticsearch.yml
├── docker-compose.es01.yml
├── docker-compose.es02.yml
├── docker-compose.es03.yml
└── ilm/
    ├── observability-ilm-policy.json
    └── README.md
```

---

## ⚙️ Node Configuration

Each node uses the same cluster configuration pattern with its own node identity and certificate files.

Example:

```yaml
cluster.name: portfolio-observability
node.name: es01
node.roles: [ master, data, ingest ]

network.host: 192.0.2.31
http.port: 9200
transport.port: 9300

discovery.seed_hosts:
  - "192.0.2.31:9300"
  - "192.0.2.32:9300"
  - "192.0.2.33:9300"

xpack.monitoring.collection.enabled: true
xpack.security.enabled: true
```

The other nodes follow the same model with their corresponding node name, address, and certificates.

---

## 💾 Persistence & Snapshots

The Compose deployment keeps Elasticsearch data outside the container:

```text
/opt/elastic/es01/data      → Elasticsearch data
/opt/elastic/es01/certs     → node certificates
/opt/elastic/snapshots      → snapshot repository
```

The snapshot repository is exposed to Elasticsearch through:

```yaml
path.repo: ["/mnt/snapshots"]
```

This keeps container replacement separate from persistent Elasticsearch data.

---

## 🔄 Index Lifecycle Management

The implemented lifecycle is intentionally simple:

```text
                ┌─────────────────────┐
                │         HOT         │
                │                     │
                │  10 GB primary      │
                │  shard OR 1 day     │
                └──────────┬──────────┘
                           │
                       ROLLOVER
                           │
                           ▼
                ┌─────────────────────┐
                │        WARM         │
                │                     │
                │      after 1d       │
                └──────────┬──────────┘
                           │
                        30 days
                           │
                           ▼
                ┌─────────────────────┐
                │       DELETE        │
                └─────────────────────┘
```

| Phase | Current implementation |
|---|---|
| **Hot** | Rollover at `10 GB` primary-shard size or `1 day` |
| **Warm** | Starts after `1 day` |
| **Delete** | Deletes data after `30 days` |

Policy: `ilm/observability-ilm-policy.json`

The lifecycle is designed to work with a stable rollover alias so ingestion clients do not need to know the physical backing-index name.

---

## 🚀 Deployment

### 1. Prepare the host

Set the required Linux kernel value on each Elasticsearch host:

```bash
sudo sysctl -w vm.max_map_count=262144
```

Persist it when required:

```bash
echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-elasticsearch.conf
sudo sysctl --system
```

### 2. Prepare certificates

Use the certificate workflow under:

```text
certificates/elasticsearch/
```

Each node requires its corresponding HTTP and transport certificate files.

### 3. Prepare secrets

Create the local environment file from:

```text
env/elastic.env.example
```

Set the required password locally. **Do not commit the real environment file.**

### 4. Start the nodes

Start the nodes sequentially:

```bash
cd elasticsearch
set -a; source ../env/elastic.env; set +a

docker compose -f docker-compose.es01.yml up -d
```

Then repeat for `es02` and `es03` on their respective hosts.

Check startup:

```bash
docker logs -f es01
```

---

## 🩺 Verify the Cluster

Cluster health:

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_cluster/health?pretty"
```

List nodes:

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_cat/nodes?v"
```

Expected result:

```text
3 Elasticsearch nodes
cluster status: green
```

A newly started cluster can temporarily report `yellow` while replicas are being allocated.

---

## 🔎 ILM Verification

Check the lifecycle policy:

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_ilm/policy/observability-ilm-policy?pretty"
```

Check an index's lifecycle state:

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/<INDEX_NAME>/_ilm/explain?pretty"
```

These checks are the first place to look when rollover does not happen as expected.

---

## 🔧 Operational Checks

### Cluster health

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_cluster/health?pretty"
```

### Node status

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_cat/nodes?v"
```

### Index status

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_cat/indices?v"
```

### Container logs

```bash
docker logs --tail 200 es01
docker logs --tail 200 es02
docker logs --tail 200 es03
```

---

## 🔑 Password Operations

Built-in user passwords can be reset from a running Elasticsearch container:

```bash
docker exec -it es01 bin/elasticsearch-reset-password -u elastic -i
docker exec -it es01 bin/elasticsearch-reset-password -u kibana_system -a -y
docker exec -it es01 bin/elasticsearch-reset-password -u logstash_system -a -y
```

Keep generated passwords outside Git and outside public documentation.

---

## 🧯 Troubleshooting Flow

```text
                  Cluster problem?
                         │
                         ▼
                 Check cluster health
                         │
              ┌──────────┴──────────┐
              │                     │
           Healthy               Unhealthy
              │                     │
              ▼                     ▼
        Check ILM state       Check node logs
              │                     │
              ▼                     ▼
       Check rollover         Check TLS / certs
              │                     │
              ▼                     ▼
       Check alias/index      Check discovery
```

For rollover problems, inspect these in order:

1. cluster health
2. index settings
3. rollover alias
4. ILM policy
5. `_ilm/explain`
6. Elasticsearch logs

---

## 🛡️ Design Principles

| Principle | Implementation |
|---|---|
| High availability | 3-node cluster |
| Node roles | master + data + ingest |
| Node communication | TLS |
| Client communication | HTTPS/TLS |
| Persistence | Host-mounted data |
| Lifecycle | ILM + rollover |
| Retention | 30 days |
| Snapshots | Local repository path |
| Deployment | Docker Compose |
| Secret handling | Environment file kept outside Git |

---

<div align="center">

### Elasticsearch Data Path

`Secure Client` → `HTTPS` → `3-Node Cluster` → `ILM Rollover` → `Warm` → `Delete`

<br>

**Secure. Persistent. Observable. Operationally predictable.**

</div>
