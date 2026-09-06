<div align="center">

# 🔄 Elasticsearch ILM

### Rollover • Warm Phase • 30-Day Retention • Stable Write Alias

![Elasticsearch](https://img.shields.io/badge/Elasticsearch-9.3.3-005571?logo=elasticsearch)
![Lifecycle](https://img.shields.io/badge/Lifecycle-ILM%20%2B%20Rollover-success)
![Retention](https://img.shields.io/badge/Retention-30%20days-orange)

</div>

---

## 🧭 Architecture at a Glance

```text
🚚 Logstash
    │
    ▼
 demo-logs alias
    │
    ▼
 demo-logs-000001
    │
 ┌──┴─────────┐
 ▼            ▼
10 GB        1 day
 │            │
 └─────┬──────┘
       ▼
   🔄 Rollover
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

---

## 🧩 Implementation at a Glance

| Capability | Implementation |
|---|---|
| Elasticsearch | `9.3.3` |
| Lifecycle owner | Elasticsearch ILM |
| Rollover | Primary-shard size or age |
| Size threshold | `10 GB` |
| Age threshold | `1 day` |
| Warm phase | After `1 day`, no extra action |
| Delete phase | After `30 days` |
| Write target | `demo-logs` alias |
| Bootstrap | Dedicated script |

---

## 🧠 Responsibility Boundary

```text
Logstash
   │
   │ stable alias
   ▼
Elasticsearch
   │
   ├── template relationship
   ├── write alias
   ├── ILM policy
   └── backing-index generations
```

The ingestion layer should not need to know which numbered backing index is active.

---

## 🧱 Lifecycle Model

The implementation has three deliberate steps:

```text
1️⃣ ILM policy
      ↓
2️⃣ Index template
      ↓
3️⃣ Bootstrap index + write alias
      ↓
4️⃣ ILM-managed rollover
```

The template associates matching indices with the lifecycle policy and rollover alias. The bootstrap operation assigns `is_write_index: true` to the first index.

This distinction prevents every future backing index from being treated as the write index.

---

## 📁 Repository Layout

```text
elasticsearch/ilm/
├── README.md
└── observability-ilm-policy.json

elasticsearch/templates/
├── observability-index-template.json
├── create-rollover-index.sh
└── README.md
```

---

## 🚀 Deployment

### 1. Apply the policy

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  -X PUT \
  "https://<ELASTICSEARCH_HOST>:9200/_ilm/policy/observability-ilm-policy" \
  -H 'Content-Type: application/json' \
  --data-binary @observability-ilm-policy.json
```

### 2. Apply the index template

Register `../templates/observability-index-template.json`.

### 3. Bootstrap the first index

```bash
../templates/create-rollover-index.sh
```

### 4. Start ingestion

Logstash writes to `demo-logs`, not directly to a numbered backing index.

---

## 🔎 Verification

### Policy

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_ilm/policy/observability-ilm-policy?pretty"
```

### Alias

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_alias/demo-logs?pretty"
```

### ILM state

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/demo-logs-*/_ilm/explain?pretty"
```

---

## 🧯 Troubleshooting Flow

```text
Policy exists?
     ↓
Template applied?
     ↓
Alias correct?
     ↓
Exactly one write index?
     ↓
ILM explain healthy?
     ↓
Threshold reached?
     ↓
Rollover
```

### Size confusion

The configured condition is `max_primary_shard_size`. Total index store size is not the same measurement.

### Age confusion

Verify the index lifecycle timestamps and `_ilm/explain` output before changing the policy.

### Alias confusion

Check that exactly one backing index has `is_write_index: true`.

---

## 🧠 Operational Decisions

| Decision | Why |
|---|---|
| Stable alias | Decouple ingestion from physical index generations |
| ES-side ILM | Keep lifecycle ownership with storage |
| Size + age rollover | Protect against both large shards and long-lived indices |
| Explicit bootstrap | Make the initial write-index state deterministic |
| 30-day deletion | Control storage growth |
| No unsupported snapshot action | Keep policy aligned with the implemented deployment |

---

## 🧪 Practical Failure Story

A useful interview scenario is an index that has exceeded an expected storage threshold but has not rolled over:

```text
Observed store size
       │
       ▼
Check policy condition
       │
       ▼
max_primary_shard_size?
       │
       ▼
Check _ilm/explain
       │
       ▼
Check alias / write index
       │
       ▼
Confirm threshold + lifecycle state
```

The important lesson is to validate **what the policy actually measures** before changing the configuration.

---

## 🔒 Portfolio Safety

Public examples contain placeholders only. No production addresses, credentials, private keys, or environment-specific identifiers belong here.

---

<div align="center">

### Policy → Template → Bootstrap → Rollover → Retention

**Deterministic. Observable. Storage-aware. Operationally explainable.**

</div>
