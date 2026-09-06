# Elasticsearch Index Template & Rollover

<div align="center">

### Stable Writes. Managed Indices. Predictable Rotation.

`Template` → `Alias` → `demo-logs-000001` → `Rollover` → `demo-logs-000002` → `…`

</div>

---

## 🧩 Design

The ingestion layer writes to a stable alias instead of addressing backing indices directly.

```text
                     ┌───────────────────────┐
                     │      Producers        │
                     └───────────┬───────────┘
                                 │
                                 ▼
                     ┌───────────────────────┐
                     │      Write Alias      │
                     │       demo-logs       │
                     └───────────┬───────────┘
                                 │
                                 ▼
                     ┌───────────────────────┐
                     │   demo-logs-000001    │
                     │      write index      │
                     └───────────┬───────────┘
                                 │
                         ILM rollover
                                 │
                                 ▼
                     ┌───────────────────────┐
                     │   demo-logs-000002    │
                     │      write index      │
                     └───────────────────────┘
```

The client-facing alias remains unchanged while ILM rotates the backing index.

---

## 📁 Files

| File | Purpose |
|---|---|
| `observability-index-template.json` | Applies lifecycle and rollover settings to matching indices |
| `create-rollover-index.sh` | Creates the first index and marks the alias as the write index |

---

## ⚙️ Template Settings

The template applies:

```json
{
  "index.lifecycle.name": "observability-ilm-policy",
  "index.lifecycle.rollover_alias": "demo-logs"
}
```

The template targets:

```text
demo-logs-*
```

The fictional names are intentionally portfolio-safe and must be replaced locally for a real environment.

---

## 🚀 Deployment Order

### 1. Create the ILM policy

Apply:

```text
../ilm/observability-ilm-policy.json
```

### 2. Register the index template

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  -X PUT \
  "https://<ELASTICSEARCH_HOST>:9200/_index_template/observability-index-template" \
  -H 'Content-Type: application/json' \
  --data-binary @observability-index-template.json
```

### 3. Create the initial write index

```bash
./create-rollover-index.sh
```

This creates:

```text
demo-logs-000001
```

with:

```text
demo-logs → demo-logs-000001 (write index)
```

### 4. Point ingestion to the alias

Applications and pipelines should write to:

```text
demo-logs
```

not directly to a numbered backing index.

---

## 🔎 Verify

Template:

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_index_template/observability-index-template?pretty"
```

Alias:

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_alias/demo-logs?pretty"
```

ILM state:

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/demo-logs-*/_ilm/explain?pretty"
```

---

## 🛠️ Rollover Troubleshooting

If rollover appears not to happen, check these in order:

```text
Template applied?
       │
       ▼
ILM policy attached?
       │
       ▼
Rollover alias configured?
       │
       ▼
Exactly one write index?
       │
       ▼
ILM explain state?
       │
       ▼
Age / shard-size condition reached?
```

A small index should **not** be expected to roll over merely because ILM is enabled. The configured rollover thresholds must actually be reached.

---

## 🔐 Credential Safety

Credentials are intentionally represented as placeholders:

```text
CHANGE_ME_*
<PASSWORD>
<ELASTICSEARCH_HOST>
```

Do not commit real passwords, private addresses, certificates, tokens, or environment-specific identifiers.

---

<div align="center">

**Stable alias in front. ILM in control. Backing indices rotate automatically.**

</div>
