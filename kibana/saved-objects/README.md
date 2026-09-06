<div align="center">

# 📦 Kibana Saved Objects

### Data View • Visualizations • Dashboard • Portable NDJSON

![Kibana](https://img.shields.io/badge/Kibana-9.3.3-005571?logo=kibana)
![Format](https://img.shields.io/badge/Format-NDJSON-blue)
![Dashboard](https://img.shields.io/badge/Objects-Portable-success)

</div>

---

## 🧭 Architecture at a Glance

```text
🔎 Elasticsearch
       │
       │ indexed events
       ▼
📊 Kibana Data View
       │
       ├── event volume
       ├── service/source distribution
       ├── log-level distribution
       └── dashboard
              │
              ▼
       📦 Saved Objects NDJSON
```

---

## 🧩 Bundle at a Glance

| Object | Purpose |
|---|---|
| Data View | `demo-logs-*` |
| Time field | `@timestamp` |
| Visualization | Events over time |
| Visualization | Events by service/source |
| Visualization | Events by log level |
| Dashboard | Enterprise Observability dashboard |
| Format | NDJSON |

---

## 🧠 Responsibility Boundary

Saved Objects describe the **Kibana presentation layer**. They do not create ingestion pipelines or replace Elasticsearch mappings.

```text
Elasticsearch fields
        │
        ▼
     Data View
        │
        ▼
 Visualizations
        │
        ▼
   Dashboard
```

The dashboard should be aligned with the fields actually produced by the target deployment.

---

## 📁 Repository Layout

```text
kibana/
├── saved-objects.ndjson
└── saved-objects/
    └── README.md
```

---

## 🚀 Import

### UI

1. Open **Stack Management → Saved Objects**.
2. Select **Import**.
3. Select `../saved-objects.ndjson`.
4. Allow overwrite when intentionally updating existing portfolio objects.
5. Open the dashboard.

### API

```bash
curl --fail --silent --show-error \
  -X POST "${KIBANA_URL}/api/saved_objects/_import?overwrite=true" \
  -H 'kbn-xsrf: true' \
  -H 'Content-Type: application/ndjson' \
  --data-binary @kibana/saved-objects.ndjson
```

Use a locally defined `KIBANA_URL` and local authentication. Never commit environment-specific addresses or credentials.

---

## 🔎 Verification

After import, verify:

```text
Saved Objects imported
        ↓
Data View exists
        ↓
@timestamp available
        ↓
Visualizations load
        ↓
Dashboard loads
        ↓
Events appear
```

For a structural repository check, run:

```bash
bash ./scripts/validate-kibana-saved-objects.sh
```

---

## 🧯 Troubleshooting Flow

```text
Dashboard empty?
      ↓
Data View correct?
      ↓
Elasticsearch contains documents?
      ↓
@timestamp exists?
      ↓
Visualization fields exist?
      ↓
Imported objects match target Kibana version?
```

If the mapping differs, export compatible objects from the target Kibana deployment rather than manually editing generated migration metadata.

---

## 🧠 Operational Decisions

| Decision | Why |
|---|---|
| Portable NDJSON | Reproducible dashboard deployment |
| Stable Data View | Decouple UI from physical index generations |
| `@timestamp` | Consistent time-based investigation |
| Version-aligned exports | Saved Objects are version-sensitive |
| Field-driven panels | Avoid dashboards that depend on unavailable fields |

---

## 🧪 Practical Failure Story

A healthy Kibana instance with an empty dashboard is not necessarily a Kibana failure.

```text
Dashboard
   ↓
Data View
   ↓
Elasticsearch query
   ↓
Documents / fields
   ↓
Upstream ingestion
```

This backward path helps distinguish a visualization problem from an ingestion or mapping problem.

---

## 🔒 Portfolio Safety

The bundle uses fictional data-view/topic/index identifiers and contains no credentials, private keys, or environment-specific addresses.

---

<div align="center">

### Export → Import → Validate → Visualize

**Portable. Version-aware. Field-driven. Operationally explainable.**

</div>
