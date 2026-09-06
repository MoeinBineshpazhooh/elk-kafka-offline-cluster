# Elasticsearch ILM

<div align="center">

### Lifecycle Management for the Observability Data Path

`Index Template` → `Write Alias` → `Rollover` → `Warm` → `Delete`

</div>

---

## 🎯 Purpose

This directory contains the lifecycle policy used by the Elasticsearch layer of the portfolio observability platform.

The implementation keeps lifecycle management simple and operationally predictable:

- rollover by primary-shard size
- rollover by age
- warm phase after the hot period
- automatic deletion after the retention period
- alias-based writes for rollover-compatible ingestion

No application-specific infrastructure identifiers are required in these files.

---

## 🔄 Lifecycle

```text
                 ┌──────────────────────┐
                 │  Write Index Alias   │
                 └──────────┬───────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │         HOT          │
                 │                      │
                 │  max shard: 10 GB    │
                 │  max age:    1 day   │
                 └──────────┬───────────┘
                            │
                         rollover
                            │
                            ▼
                 ┌──────────────────────┐
                 │        WARM          │
                 │                      │
                 │     after 1 day      │
                 └──────────┬───────────┘
                            │
                         30 days
                            │
                            ▼
                 ┌──────────────────────┐
                 │       DELETE         │
                 │                      │
                 │   retention: 30d     │
                 └──────────────────────┘
```

## 📋 Current Policy

| Phase | Condition | Action |
|---|---|---|
| Hot | Primary shard reaches 10 GB **or** index reaches 1 day | Rollover |
| Warm | 1 day | No additional action defined |
| Delete | 30 days | Delete index |

The policy intentionally does not add extra tiering or allocation rules that are not part of the current implementation.

---

## 📁 Files

```text
elasticsearch/
└── ilm/
    ├── observability-ilm-policy.json
    └── README.md
```

---

## 🚀 Apply the Policy

Authenticate to Elasticsearch and create/update the lifecycle policy using the JSON file:

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  -X PUT \
  "https://<ELASTICSEARCH_HOST>:9200/_ilm/policy/observability-ilm-policy" \
  -H 'Content-Type: application/json' \
  --data-binary @observability-ilm-policy.json
```

> Replace placeholders locally. Do not commit credentials or private infrastructure values.

---

## 🔎 Verify

Check the policy:

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/_ilm/policy/observability-ilm-policy?pretty"
```

Check the lifecycle status of an index:

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/<INDEX_NAME>/_ilm/explain?pretty"
```

---

## 🔗 Rollover Compatibility

The policy is intended to be used with an index template and rollover alias.

The resulting ingestion pattern is:

```text
Producer
   │
   ▼
Log ingestion pipeline
   │
   ▼
Write alias
   │
   ▼
Current write index
   │
   ├── 10 GB reached ──┐
   └── 1 day reached ──┤
                       ▼
                    Rollover
                       │
                       ▼
                 New write index
```

The alias remains stable for clients while Elasticsearch creates successive backing indices.

---

## 🛡️ Operational Notes

- Keep the policy name stable once referenced by templates.
- Apply the policy before creating the first rollover-managed index.
- Verify the write alias points to exactly one current write index.
- Monitor ILM state with `_ilm/explain` when troubleshooting rollover.
- Keep credentials outside Git.

---

<div align="center">

**Simple lifecycle. Predictable retention. Operationally focused.**

</div>
