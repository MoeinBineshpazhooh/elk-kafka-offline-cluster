<div align="center">

# 🔄 Elasticsearch ILM

### Predictable Rollover and Retention for Observability Data

**Rollover · Warm phase · 30-day retention · Stable write alias**

</div>

---

## 🧭 Purpose

This directory defines the Elasticsearch Index Lifecycle Management policy used by the observability data path.

The design keeps lifecycle ownership inside Elasticsearch. Ingestion clients write to a stable alias and do not need to know which numbered backing index is currently active.

```text
                    Logstash
                       │
                       ▼
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

---

## 🎯 Current Policy

| Phase | Trigger / Age | Action |
|---|---|---|
| **Hot** | Primary shard `10 GB` or index age `1 day` | Rollover |
| **Warm** | `1 day` | No additional action configured |
| **Delete** | `30 days` | Delete index |

Policy file:

```text
observability-ilm-policy.json
```

The policy intentionally does not introduce additional allocation, snapshot, or tiering actions that are not part of the implemented configuration.

---

## 🧱 Architecture

ILM is one part of a three-stage Elasticsearch lifecycle configuration:

```text
1. ILM Policy
       │
       ▼
2. Index Template
       │
       │ lifecycle.name
       │ rollover_alias
       ▼
3. Bootstrap Index + Write Alias
       │
       ▼
4. Elasticsearch manages rollover
```

The important separation is that the **template describes the lifecycle relationship**, while the **bootstrap operation creates the first write index and assigns the initial write flag**.

This prevents every future backing index from inheriting `is_write_index: true`.

---

## 📁 Repository Layout

```text
elasticsearch/
├── ilm/
│   ├── observability-ilm-policy.json
│   └── README.md
└── templates/
    ├── observability-index-template.json
    ├── create-rollover-index.sh
    └── README.md
```

---

## 🚀 Deployment Order

### Step 1 — Apply the ILM policy

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  -X PUT \
  "https://<ELASTICSEARCH_HOST>:9200/_ilm/policy/observability-ilm-policy" \
  -H 'Content-Type: application/json' \
  --data-binary @observability-ilm-policy.json
```

### Step 2 — Apply the index template

Register the template under:

```text
../templates/observability-index-template.json
```

The template associates matching indices with:

```text
observability-ilm-policy
demo-logs
```

### Step 3 — Bootstrap the first index

Run:

```bash
../templates/create-rollover-index.sh
```

The bootstrap creates the initial numbered index and marks the alias as its write index.

### Step 4 — Start ingestion

Logstash writes to:

```text
demo-logs
```

not directly to `demo-logs-000001` or later backing indices.

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

### Index generation

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_cat/indices/demo-logs-*?v"
```

---

## 🧯 Rollover Troubleshooting

A rollover condition being configured does not mean rollover occurs immediately. The configured age or primary-shard-size threshold must be reached.

Use this sequence:

```text
Policy exists?
      │
      ▼
Template applied?
      │
      ▼
Alias configured?
      │
      ▼
Exactly one write index?
      │
      ▼
ILM explain healthy?
      │
      ▼
Threshold actually reached?
      │
      ▼
Rollover occurs
```

### Multiple write indices

If more than one backing index is marked as the write index, correct the alias before continuing. The bootstrap script is intentionally responsible for assigning the initial write flag.

### Rollover did not happen at the expected size

Check the primary-shard size rather than total index-store size. The policy uses `max_primary_shard_size`.

### Rollover did not happen at the expected age

Check the ILM explain output and index creation/lifecycle timestamps. Verify that the index is managed by the expected policy.

---

## 🛡️ Operational Principles

- Keep the ILM policy name stable once referenced by the index template.
- Keep the write alias stable for ingestion clients.
- Bootstrap the first write index explicitly.
- Maintain exactly one active write index for the alias.
- Treat the numbered backing-index names as implementation details.
- Validate `_ilm/explain` before changing policy settings.
- Keep credentials and private infrastructure values outside Git.

---

## 🔒 Portfolio Safety

The policy and documentation contain only fictional, portfolio-safe identifiers and placeholders.

Never commit:

- production addresses
- passwords or tokens
- private keys
- private certificates
- environment-specific registry names

---

<div align="center">

### Policy → Template → Bootstrap → Rollover → Retention

**Elasticsearch owns the lifecycle. Clients keep a stable write target.**

</div>
