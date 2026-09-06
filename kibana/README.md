<div align="center">

# 📊 Kibana Observability UI

### Elasticsearch HTTPS • Data Views • Saved Objects • Operational Dashboard

![Kibana](https://img.shields.io/badge/Kibana-9.3.3-005571?logo=kibana)
![Elasticsearch](https://img.shields.io/badge/Elasticsearch-HTTPS-005571?logo=elasticsearch)
![Dashboard](https://img.shields.io/badge/UI-Saved%20Objects-blue)
![Deployment](https://img.shields.io/badge/Deployment-Docker%20Compose-orange)

</div>

---

## 🧭 Architecture at a Glance

```text
Filebeat → Kafka → Logstash → Elasticsearch
                                  │
                                  │ HTTPS
                                  ▼
                         ┌────────────────┐
                         │ 📊 Kibana      │
                         │                │
                         │ Data Views     │
                         │ Visualizations │
                         │ Dashboard      │
                         └────────────────┘
```

---

## 🧩 Implementation at a Glance

| Capability | Implementation |
|---|---|
| Version | `9.3.3` |
| Deployment | Docker Compose per host |
| Network model | Host networking |
| Elasticsearch connection | HTTPS |
| CA trust | Mounted Elasticsearch CA |
| Client modes | HTTP and HTTPS variants |
| Security keys | Environment-supplied and persistent |
| Dashboard | Portable NDJSON Saved Objects |
| Data View | `demo-logs-*` |
| Time field | `@timestamp` |
| Runtime | Air-gapped / offline-capable |

---

## 🧠 Responsibility Boundary

Kibana owns **investigation, visualization, and presentation**.

```text
🔎 Elasticsearch
       │
       │ search
       ▼
📊 Kibana
       │
       ├── Data View
       ├── visualizations
       └── operational dashboard
```

Kibana does not own ingestion, Kafka transport, Logstash processing, or Elasticsearch lifecycle management.

---

## 🔐 Security Model

### Kibana → Elasticsearch

```text
Kibana
  │
  │ HTTPS + CA validation
  ▼
Elasticsearch
```

The service uses the `kibana_system` identity, with its credential supplied outside Git.

### Client → Kibana

Two Compose variants are provided:

| Mode | Purpose |
|---|---|
| HTTP | Internal/trusted-network example |
| HTTPS | Encrypted client-to-Kibana traffic |

The HTTPS variant mounts the Kibana server certificate and private key read-only.

### Encryption keys

Kibana security, encrypted Saved Objects, and reporting keys are supplied through the local environment and must remain stable for the deployment lifetime.

---

## 📁 Repository Layout

```text
kibana/
├── README.md
├── docker-compose.kibana01.yml
├── docker-compose.kibana01.https.yml
├── docker-compose.kibana02.yml
├── docker-compose.kibana02.https.yml
├── saved-objects.ndjson
└── saved-objects/
    └── README.md
```

---

## ⚙️ Configuration Model

```text
             env/kibana.env.example
                       │
                       ▼
              local env/kibana.env
                       │
             ┌─────────┴─────────┐
             ▼                   ▼
      Elasticsearch           Kibana server
       connection             HTTP/HTTPS mode
```

The public environment file is a contract. Deployment-specific endpoints, credentials, encryption keys, and certificate material remain local.

---

## 📊 Saved Objects & Dashboard

The repository contains a portable NDJSON bundle:

```text
kibana/saved-objects.ndjson
```

It provides:

- `demo-logs-*` Data View
- `@timestamp` time field
- event-volume visualization
- service/source distribution
- log-level distribution
- combined operational dashboard

Import through **Stack Management → Saved Objects → Import** or the Saved Objects API.

Saved Objects are version-sensitive. Re-export from the target Kibana version when upgrading rather than manually editing generated migration metadata.

---

## 🚀 Deployment

### HTTP mode

```bash
docker compose -f docker-compose.kibana01.yml up -d
docker logs -f kibana01
```

### HTTPS mode

```bash
docker compose -f docker-compose.kibana01.https.yml up -d
docker logs -f kibana01
```

Repeat with the corresponding second-host Compose file.

---

## 🔎 Verification

Check the container:

```bash
docker ps --filter name=kibana01
docker logs --tail 200 kibana01
```

Check Kibana status:

```bash
curl --fail "http://<KIBANA_HOST>:5601/api/status"
```

For HTTPS mode, use the corresponding HTTPS endpoint and CA trust.

Then verify the Data View and dashboard after importing Saved Objects.

---

## 🧯 Troubleshooting Flow

```text
Kibana unavailable?
       │
       ▼
Container / startup logs
       │
       ▼
Elasticsearch HTTPS reachable?
       │
       ▼
CA + kibana_system credentials valid?
       │
       ▼
Server certificate/key valid?
       │
       ▼
Encryption keys present and stable?
       │
       ▼
Saved Objects imported?
       │
       ▼
Data View fields match events?
```

### Dashboard has no data

Check the data path first, then confirm the Data View pattern and fields such as `@timestamp`, `service.source`, `log.level`, and `message` exist where the visualizations require them.

---

## 🧠 Operational Decisions

| Decision | Why |
|---|---|
| 9.3.3 | Current platform version |
| HTTPS to Elasticsearch | Protect UI-to-search traffic |
| CA validation | Prevent trusting arbitrary Elasticsearch endpoints |
| Persistent encryption keys | Preserve encrypted Kibana data across restarts |
| Saved Objects | Make the dashboard portable and reproducible |
| HTTP + HTTPS variants | Support both internal and encrypted client access patterns |
| Compose per host | Match the distributed deployment model |

---

## 🧪 Practical Failure Story

When Kibana is healthy but the dashboard is empty, troubleshoot **backwards through the data path** rather than changing the dashboard immediately:

```text
Dashboard
   ↓
Data View
   ↓
Elasticsearch documents
   ↓
Logstash indexing
   ↓
Kafka consumption
   ↓
Filebeat publication
```

This avoids confusing a presentation problem with an ingestion problem.

---

## 🔒 Portfolio Safety

Public examples contain placeholders only. No production addresses, credentials, private keys, registry names, or environment-specific identifiers belong in Git.

---

<div align="center">

### 🔎 Elasticsearch → 📊 Kibana → 📈 Operational Visibility

**Secure. Portable. Reproducible. Operationally explainable.**

</div>
