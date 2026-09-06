<div align="center">

# 🧱 Elasticsearch Index Template & Rollover

### Stable Alias • Template Contract • Bootstrap • ILM Rollover

![Elasticsearch](https://img.shields.io/badge/Elasticsearch-9.3.3-005571?logo=elasticsearch)
![Lifecycle](https://img.shields.io/badge/Lifecycle-ILM-success)
![Rollover](https://img.shields.io/badge/Rollover-Alias-orange)

</div>

---

## 🧭 Architecture at a Glance

```text
🚚 Producers
     │
     ▼
┌───────────────────┐
│ demo-logs alias   │
└─────────┬─────────┘
          ▼
┌───────────────────┐
│ demo-logs-000001  │
│   write index     │
└─────────┬─────────┘
          │ ILM rollover
          ▼
┌───────────────────┐
│ demo-logs-000002  │
│   write index     │
└───────────────────┘
```

---

## 🧩 Implementation at a Glance

| Component | Purpose |
|---|---|
| Index template | Attaches lifecycle and rollover settings |
| `observability-ilm-policy` | Defines rollover/retention behavior |
| `demo-logs` | Stable ingestion alias |
| Bootstrap script | Creates the initial write index |
| Backing indices | Physical rollover generations |

---

## 🧠 Responsibility Boundary

```text
Template
   │
   ├── lifecycle policy
   └── rollover alias

Bootstrap script
   │
   └── initial is_write_index

ILM
   │
   └── subsequent rollover generations

Logstash
   │
   └── writes only to stable alias
```

This keeps ingestion independent from physical index names.

---

## 📁 Repository Layout

```text
elasticsearch/templates/
├── README.md
├── observability-index-template.json
└── create-rollover-index.sh
```

---

## ⚙️ Template Contract

The template associates matching indices with the lifecycle policy and rollover alias:

```json
{
  "index.lifecycle.name": "observability-ilm-policy",
  "index.lifecycle.rollover_alias": "demo-logs"
}
```

The example pattern is:

```text
demo-logs-*
```

The template deliberately does **not** assign `is_write_index: true`. That flag belongs to the bootstrap alias operation.

---

## 🚀 Deployment

### 1. Apply ILM first

```text
../ilm/observability-ilm-policy.json
```

### 2. Register the template

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  -X PUT \
  "https://<ELASTICSEARCH_HOST>:9200/_index_template/observability-index-template" \
  -H 'Content-Type: application/json' \
  --data-binary @observability-index-template.json
```

### 3. Bootstrap the first index

```bash
./create-rollover-index.sh
```

The result is:

```text
demo-logs → demo-logs-000001
```

with the initial backing index marked as the write index.

### 4. Start ingestion

Point Logstash to `demo-logs`, not to a numbered backing index.

---

## 🔎 Verification

### Template

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_index_template/observability-index-template?pretty"
```

### Alias

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_alias/demo-logs?pretty"
```

### Lifecycle

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/demo-logs-*/_ilm/explain?pretty"
```

---

## 🧯 Troubleshooting Flow

```text
Template applied?
      ↓
ILM attached?
      ↓
Alias configured?
      ↓
Exactly one write index?
      ↓
ILM explain healthy?
      ↓
Threshold reached?
      ↓
Rollover
```

A configured rollover threshold does not force an immediate rollover; the relevant age or primary-shard-size condition must be reached.

---

## 🧠 Operational Decisions

| Decision | Why |
|---|---|
| Stable alias | Producers remain independent of backing indices |
| Explicit bootstrap | Initial write state is deterministic |
| No write flag in template | Prevent multiple write-index conflicts |
| ILM-owned rollover | Elasticsearch controls index generations |
| Numbered indices | Keep physical generations explicit and inspectable |

---

## 🧪 Practical Failure Story

If an index appears larger than expected but does not roll over, verify the **actual policy metric** first:

```text
Observed total store size
          │
          ▼
Policy uses primary-shard size?
          │
          ▼
Check _ilm/explain
          │
          ▼
Check alias / write index
          │
          ▼
Confirm threshold
```

This prevents changing ILM configuration based on the wrong measurement.

---

## 🔒 Portfolio Safety

All addresses, credentials, private keys, and environment-specific identifiers remain outside Git. Example names are fictional and intended only as documentation contracts.

---

<div align="center">

### Template → Alias → Bootstrap → Rollover

**Stable writes. Explicit state. Predictable index generations.**

</div>
