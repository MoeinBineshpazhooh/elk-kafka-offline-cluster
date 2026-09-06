<div align="center">

# 🔎 Elasticsearch

### 3-Node Secure Search & Observability Cluster

**Elasticsearch 9.2.4 · Docker Compose · TLS · Security · ILM · Rollover**

</div>

---

## 🧭 Role in the Platform

Elasticsearch is the secured storage and search layer for the observability pipeline. It receives processed events from Logstash over HTTPS, stores them across a three-node cluster, and manages log retention through Elasticsearch-native ILM and rollover.

```text
Filebeat
    │
    ▼
Kafka KRaft
    │
    ▼
Logstash
    │ HTTPS + CA validation
    ▼
┌──────────────────────────────────┐
│      Elasticsearch Cluster       │
│                                  │
│  ES01        ES02        ES03    │
│  master      master      master  │
│  data        data        data    │
│  ingest      ingest      ingest  │
└──────────────────────────────────┘
    │
    ├── ILM / rollover
    ├── persistent storage
    └── Kibana search & visualization
```

The implementation deliberately uses three combined-role nodes rather than introducing additional tiers that are not part of the current deployment.

---

## 🎯 What This Implements

- three Elasticsearch nodes
- `master`, `data`, and `ingest` roles on each node
- K/V configuration separated per node
- Docker Compose deployment per host
- persistent host-mounted data
- HTTPS on the Elasticsearch HTTP layer
- TLS on the transport layer
- Elasticsearch security enabled
- monitoring collection enabled
- local snapshot repository path
- ILM with rollover, warm, and delete phases
- stable write-alias architecture

---

## 🖥️ Node Topology

| Node | Roles | HTTP | Transport | Deployment |
|---|---|---:|---:|---|
| `es01` | master · data · ingest | `9200` | `9300` | Compose on node 01 |
| `es02` | master · data · ingest | `9200` | `9300` | Compose on node 02 |
| `es03` | master · data · ingest | `9200` | `9300` | Compose on node 03 |

All addresses are intentionally represented by placeholders in the public configuration. Replace them locally through the environment/configuration workflow.

---

## 🔐 Security Architecture

### Client traffic

```text
Logstash / Kibana / Admin Client
              │
              │ HTTPS + TLS
              ▼
     Elasticsearch HTTP :9200
              │
              ▼
      Elasticsearch Security
```

### Node-to-node traffic

```text
ES01 ◄──────── TLS ────────► ES02
  │                           │
  └────────── TLS ───────────┘
              │
             ES03
```

HTTP TLS uses node-specific PKCS#12 material. Transport TLS protects inter-node communication. The Elasticsearch CA is distributed only to components that need to establish trusted client connections.

Credentials and private keys are never stored in the repository.

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

The node configuration follows one common pattern while keeping node identity and certificate references node-specific.

Core settings include:

```yaml
cluster.name: portfolio-observability
node.name: es01
node.roles: [ master, data, ingest ]
http.port: 9200
transport.port: 9300
xpack.security.enabled: true
xpack.monitoring.collection.enabled: true
```

Discovery uses the three transport endpoints supplied by the local deployment configuration.

The Compose files use host networking and mount configuration, certificate, data, and snapshot paths from the host.

---

## 💾 Persistence

Elasticsearch data is kept outside the container filesystem so container replacement does not imply data replacement.

```text
Host data directory
        │
        ▼
/usr/share/elasticsearch/data
        │
        ▼
Persistent Elasticsearch state
```

The configuration also exposes a repository path inside the container:

```yaml
path.repo: ["/mnt/snapshots"]
```

The repository contains the configuration contract only; actual snapshot data remains outside Git.

---

## 🔄 ILM & Rollover

The lifecycle is managed by Elasticsearch, not by the Logstash output plugin in this implementation.

```text
                 Stable write alias
                         │
                         ▼
                 demo-logs-000001
                         │
              ┌──────────┴──────────┐
              │                     │
          10 GB primary            1 day
              │                     │
              └──────────┬──────────┘
                         ▼
                      Rollover
                         │
                         ▼
                 demo-logs-000002
                         │
                         ▼
                      Warm
                         │
                       30d
                         ▼
                      Delete
```

Current policy:

| Phase | Behavior |
|---|---|
| Hot | Rollover at `10 GB` primary-shard size or `1 day` |
| Warm | Begins after `1 day`; no additional action is defined |
| Delete | Deletes indices after `30 days` |

The index template supplies the lifecycle policy and rollover alias. The bootstrap script creates the first backing index and sets the write flag exactly once. Subsequent rollover generations are managed by ILM.

See `ilm/README.md` and `templates/README.md` for the operational workflow.

---

## 🚀 Deployment Sequence

### 1. Prepare the host

Configure the required Elasticsearch host prerequisites, including the kernel setting used by Elasticsearch:

```bash
sudo sysctl -w vm.max_map_count=262144
```

### 2. Prepare certificates

Generate the required node certificates using the certificate workflow in:

```text
certificates/elasticsearch/
```

Do not place generated private material in Git.

### 3. Prepare local environment values

```bash
cp env/elastic.env.example env/elastic.env
```

Set deployment-specific values locally.

### 4. Start each node

On each Elasticsearch host, run its corresponding Compose file:

```bash
docker compose -f docker-compose.es01.yml up -d
```

Repeat for the other nodes on their respective hosts.

### 5. Apply lifecycle configuration

Apply the ILM policy, index template, and bootstrap the initial rollover index in that order.

### 6. Connect ingestion

Logstash writes to the stable alias rather than a physical numbered index.

---

## 🩺 Cluster Verification

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

### Indices

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_cat/indices?v"
```

### ILM

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/<INDEX_NAME>/_ilm/explain?pretty"
```

A healthy deployment should converge on the expected three-node topology. `yellow` can be transient during shard allocation; investigate persistent non-green health before relying on the cluster operationally.

---

## 🧯 Troubleshooting Flow

```text
                 Elasticsearch issue?
                         │
                         ▼
                 Cluster health
                         │
          ┌──────────────┴──────────────┐
          │                             │
       Healthy                       Unhealthy
          │                             │
          ▼                             ▼
     Check ILM / alias           Check node logs
          │                             │
          ▼                             ▼
     Check rollover             Check discovery
          │                             │
          ▼                             ▼
   Check backing index          Check TLS / certs
```

For rollover failures, verify in this order:

1. ILM policy exists.
2. Index template is applied.
3. Rollover alias is configured.
4. Exactly one backing index has `is_write_index: true`.
5. `_ilm/explain` reports the expected policy and phase.
6. The rollover condition has actually been reached.

---

## 🧠 Operational Decisions

| Decision | Implementation |
|---|---|
| Cluster size | 3 nodes |
| Node roles | master + data + ingest |
| Client transport | HTTPS/TLS |
| Inter-node transport | TLS |
| Authentication | Elasticsearch security |
| Persistence | Host-mounted data |
| Lifecycle owner | Elasticsearch ILM |
| Rollover mechanism | Stable alias + ILM |
| Retention | 30 days |
| Snapshots | Local repository path |
| Deployment | Docker Compose per host |
| Secrets | External environment/certificate material |
| Runtime network dependency | No public registry required |

---

## 🔒 Portfolio Safety

This public repository contains only sanitized configuration contracts. It does not contain:

- production IP addresses
- production hostnames
- passwords or tokens
- private keys
- environment-specific registry names
- environment-specific infrastructure identifiers

Replace placeholders only in the local deployment environment.

---

<div align="center">

### Secure Cluster → Stable Alias → ILM Rollover → Retention

**Persistent. Secure. Searchable. Operationally predictable.**

</div>
