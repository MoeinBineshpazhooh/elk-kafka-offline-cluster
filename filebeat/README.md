<div align="center">

# 🛰️ Filebeat Edge Ingestion Layer

### Filestream • NDJSON • Persistent Registry • Kafka • SASL/PLAIN

![Filebeat](https://img.shields.io/badge/Filebeat-9.0.1-black?logo=elastic)
![Input](https://img.shields.io/badge/Input-Filestream-blue?logo=elastic)
![Transport](https://img.shields.io/badge/Transport-Kafka-orange?logo=apachekafka)
![Security](https://img.shields.io/badge/Security-SASL%2FPLAIN-blue?logo=apachekafka)
![Deployment](https://img.shields.io/badge/Deployment-Air--gapped-success)

</div>

---

## 🧭 Architecture at a Glance

```text
                    📦 Application Logs
                           │
                           │ JSON / NDJSON files
                           ▼
                 ┌──────────────────────┐
                 │      🛰️ Filebeat     │
                 │                      │
                 │  🔍 Filestream       │
                 │  🧩 NDJSON Parser    │
                 │  🏷️ Input Processors │
                 │  💾 Registry State   │
                 └──────────┬───────────┘
                            │
                            │ 🔐 SASL/PLAIN
                            ▼
                 ┌──────────────────────┐
                 │     📨 Kafka KRaft    │
                 │                      │
                 │  3 Controllers       │
                 │  3 Brokers           │
                 └──────────┬───────────┘
                            │
                            │ Consumer Group
                            ▼
                 ┌──────────────────────┐
                 │     🚚 Logstash       │
                 │  Kafka → Elasticsearch│
                 └──────────┬───────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │   🔎 Elasticsearch    │
                 └──────────┬───────────┘
                            │
                            ▼
                 ┌──────────────────────┐
                 │      📊 Kibana        │
                 └──────────────────────┘
```

> **Design goal:** Filebeat is the lightweight edge collector. It owns file discovery, reading, structured parsing, source-specific enrichment, and authenticated publication to Kafka. Kafka provides the transport boundary for downstream processing.

---

## 🧩 Implementation at a Glance

| Capability | Implementation |
|---|---|
| 🛰️ Filebeat | `9.0.1` |
| 🔍 Input | `filestream` |
| 📄 Format | NDJSON / JSON Lines |
| 🧱 Input isolation | One source configuration per file |
| ⚡ Scanner interval | `1s` |
| 🧵 Harvester limit | `0` / unlimited |
| 📦 Harvester buffer | `4194304` bytes / 4 MiB |
| 🔁 Initial backoff | `100ms` |
| 🔁 Maximum backoff | `1s` |
| 💾 Registry | Persistent Filebeat state |
| 📨 Output | Kafka |
| 🔐 Authentication | SASL/PLAIN |
| 🔒 Example protocol | `SASL_PLAINTEXT` |
| 🐳 Deployment | Docker Compose |
| 📴 Target environment | Air-gapped / offline capable |

---

## 🧠 Responsibility Boundary

Filebeat deliberately owns only the edge-ingestion responsibilities:

```text
📦 Application
      │
      │ files
      ▼
🛰️ Filebeat
      │
      ├── 🔍 discover files
      ├── 📖 harvest content
      ├── 🧩 parse NDJSON
      ├── 🏷️ enrich events
      └── 📨 publish to Kafka
                  │
                  ▼
             📨 Kafka
                  │
                  ▼
             🚚 Logstash
```

The downstream Elasticsearch output is not configured in Filebeat. That responsibility belongs to Logstash.

This separation keeps the edge collector independent from storage, indexing, and dashboard concerns.

---

## 📁 Repository Layout

```text
filebeat/
├── README.md
├── config/
│   └── filebeat.yml
├── inputs/
│   └── demo-application-logs.yml
└── docker-compose.filebeat01.yml

env/
└── filebeat.env.example
```

The configuration is intentionally split between shared runtime settings and source-specific inputs.

---

## 🧱 Configuration Model

```text
              filebeat.yml
                   │
        ┌──────────┴──────────┐
        │                     │
        ▼                     ▼
   ⚙️ Runtime              📨 Kafka Output
        │
        ▼
      inputs/
        │
   ┌────┴─────┐
   ▼          ▼
Source A    Source B
   │          │
   └────┬─────┘
        ▼
      Events
```

`config/filebeat.yml` provides the shared configuration loader and Kafka output.

Individual sources live under `inputs/` so paths, parsers, and processors remain isolated.

### Why isolate inputs?

- 🧩 Source-specific behavior stays local.
- 🏷️ Processors cannot unintentionally enrich unrelated sources.
- 📁 New log sources can be added without expanding one monolithic configuration.
- 🔎 Troubleshooting becomes easier because each source has a clear configuration boundary.

---

## 🔍 Filestream Design

The implementation uses `filestream` for continuously changing application log files.

```text
📄 active.log
     │
     │ write
     ▼
🔍 Filestream scanner
     │
     ▼
🧵 Harvester
     │
     ▼
🧩 NDJSON parser
     │
     ▼
🏷️ Input processors
     │
     ▼
📨 Kafka producer
```

This model is suited to environments where applications create, append, rotate, rename, and replace log files.

---

## ⚡ Performance Tuning

The example configuration explicitly tunes file discovery and harvesting for responsive ingestion.

| Setting | Value | Purpose |
|---|---:|---|
| `prospector.scanner.check_interval` | `1s` | Detect new or changed files quickly |
| `harvester_limit` | `0` | No artificial global harvester ceiling |
| `harvester_buffer_size` | `4194304` | 4 MiB read buffer |
| `backoff.init` | `100ms` | Fast initial retry |
| `backoff.max` | `1s` | Limits retry delay |

> These are implementation-specific tuning values, not universal recommendations. Capacity planning should still consider file count, event size, filesystem performance, CPU, and memory.

---

## 🧩 Structured Event Processing

The example source consumes newline-delimited JSON:

```text
{"timestamp":"...","level":"INFO","message":"..."}
{"timestamp":"...","level":"WARN","message":"..."}
{"timestamp":"...","level":"ERROR","message":"..."}
```

The NDJSON parser is configured to:

- decode structured fields into the event;
- overwrite decoded keys where configured;
- add an error field when parsing fails.

### 🏷️ Processor Scope

Processors are defined **inside the input**.

```text
Input A
 ├── parser
 └── processors

Input B
 ├── parser
 └── processors
```

This is intentional. Source metadata should belong to the source that generated the event rather than being applied globally to every Filebeat event.

---

## 🔐 Kafka Security Model

Filebeat publishes to Kafka using a dedicated client identity.

```text
                 🛰️ Filebeat
                      │
                      │ username + password
                      │ SASL/PLAIN
                      ▼
              ┌─────────────────┐
              │ 🔐 Kafka Auth   │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │ 🛡️ Kafka ACLs   │
              └────────┬────────┘
                       │
                    ALLOW / DENY
                       │
                       ▼
                 📨 Log Topic
```

The example uses:

```text
security.protocol = SASL_PLAINTEXT
sasl.mechanism    = PLAIN
principal         = filebeat
```

**Important:** `SASL_PLAINTEXT` authenticates the client but does **not** encrypt traffic. Use a TLS-enabled Kafka listener when confidentiality in transit is required.

The Filebeat identity should receive only the Kafka permissions required to publish its configured stream.

---

## 💾 Registry & State Persistence

Filebeat's registry is part of the ingestion reliability model.

```text
📄 Log file
    │
    ▼
🛰️ Filebeat
    │
    ├──────────────► 📨 Kafka
    │
    ▼
💾 Registry
    │
    └── file identity + read position
```

The registry must survive container recreation.

If state is lost, Filebeat may need to rediscover files and reconstruct offsets, which can lead to rereading data depending on the file state and configuration.

For this reason, the deployment mounts the Filebeat data directory persistently.

---

## 🔄 File Rotation & Permissions

Log rotation introduces two independent concerns: **file identity** and **filesystem access**.

```text
        Application
            │
            ▼
       active.log
            │
        rotation
            ▼
      archived.log
            │
            └──────► new active.log
```

A file visible on the host is not necessarily readable by the Filebeat process inside the container.

```text
Host filesystem
      │
      │ bind mount
      ▼
Container filesystem
      │
      │ ownership / mode
      ▼
Filebeat process
```

When investigating harvesting failures, check both the host-side and container-side file permissions.

Example:

```bash
ls -lah /var/log/demo-app/
```

and:

```bash
docker exec filebeat01 sh -c 'ls -lah /var/log/demo-app/'
```

Rotation scripts should also be checked for changes to ownership or mode.

---

## 📴 Air-Gapped Deployment

The component is designed for environments where runtime internet access is unavailable.

```text
          📴 Offline environment
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
   🐳 Filebeat image     ⚙️ Configuration
        │                     │
        └──────────┬──────────┘
                   ▼
              🛰️ Filebeat
                   │
                   ▼
              📨 Kafka
```

Prepare the required Filebeat image before deployment and make it available from the local image cache or approved private registry.

Environment-specific values remain outside the public repository.

---

## 🚀 Deployment

### 1. Prepare local environment values

```bash
cp env/filebeat.env.example env/filebeat.env
```

Replace the `CHANGE_ME_*` and infrastructure placeholders locally. Never commit the resulting environment file.

### 2. Prepare the mounted log directory

The example input expects:

```text
/var/log/demo-app/*.log
```

Ensure the host directory is mounted into the container and readable by the Filebeat process.

### 3. Start Filebeat

```bash
docker compose -f filebeat/docker-compose.filebeat01.yml up -d
```

### 4. Inspect the service

```bash
docker ps --filter name=filebeat01
docker logs --tail 200 filebeat01
```

---

## 🔎 Verification

### Configuration

```bash
docker run --rm \
  -v "$PWD/filebeat/config/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro" \
  -v "$PWD/filebeat/inputs:/usr/share/filebeat/inputs:ro" \
  docker.elastic.co/beats/filebeat:9.0.1 \
  filebeat test config -e
```

### File visibility

```bash
docker exec filebeat01 sh -c 'ls -lah /var/log/demo-app/'
```

### End-to-end path

```text
❶ 📄 Application writes JSON
          ↓
❷ 🔍 Filebeat discovers file
          ↓
❸ 🧵 Harvester reads records
          ↓
❹ 🧩 NDJSON parser decodes event
          ↓
❺ 🏷️ Input processors enrich event
          ↓
❻ 🔐 Kafka authentication succeeds
          ↓
❼ 📨 Kafka accepts event
          ↓
❽ 🚚 Logstash consumes event
          ↓
❾ 🔎 Elasticsearch indexes event
          ↓
❿ 📊 Kibana visualizes data
```

---

## 🧰 Troubleshooting Checklist

```text
📄 File exists?
      ↓
🔍 Filebeat discovered it?
      ↓
🧵 Harvester can read it?
      ↓
🧩 NDJSON parsing succeeds?
      ↓
🏷️ Input processors execute?
      ↓
🔐 Kafka authentication succeeds?
      ↓
🛡️ Kafka ACL permits WRITE?
      ↓
📨 Event reaches topic?
      ↓
🚚 Logstash consumes it?
      ↓
🔎 Elasticsearch stores it?
```

### File exists but is not discovered

Check the mounted path, input enablement, configured glob, and Filebeat scanner logs.

### File is discovered but not harvested

Check ownership, permissions, mount visibility, and permissions after rotation.

### Registry state is lost

Check the persistent Filebeat data mount and verify that the container is not starting against a new empty volume.

### Duplicate events after restart

Check registry persistence first. Loss of file state can cause previously processed files to be reconsidered.

### Kafka authentication failure

Verify the local bootstrap servers, username, password, SASL mechanism, security protocol, and topic configuration without exposing credentials in logs or Git.

### Kafka unavailable

Inspect Filebeat output errors and Kafka health. Filebeat should not be treated as an unlimited persistent queue during an extended downstream outage.

---

## 🛡️ Security Rules

```text
                 📁 Git Repository
                       │
             ┌─────────┴─────────┐
             │                   │
             ▼                   ▼
          ✅ SAFE              ❌ NEVER
             │                   │
       placeholders         real passwords
       examples             private keys
       templates             production certs
       documentation         access tokens
```

Operational rules:

- 🔑 Keep credentials in local ignored environment/secret files.
- 🛡️ Use a dedicated Kafka principal for Filebeat.
- 📜 Grant only the required topic permissions.
- 🔒 Use TLS when transport confidentiality is required.
- 📁 Limit host mounts to required log directories.
- 💾 Persist the Filebeat registry.

---

## 📋 Operational Checklist

| Check | Expected |
|---|---|
| Filebeat container | Running |
| Input configuration | Enabled and loaded |
| Log path | Mounted and readable |
| Filestream scanner | `1s` |
| Registry | Persistent |
| NDJSON parser | Enabled |
| Processors | Input-scoped |
| Kafka authentication | SASL/PLAIN |
| Kafka authorization | Dedicated producer permissions |
| Output topic | Configured explicitly |
| Credentials | External to Git |

---

## 🎯 Portfolio Scope

This component demonstrates the implemented Filebeat responsibilities:

- 🛰️ Filestream-based edge collection
- 🔍 High-frequency file discovery
- 📦 Tuned harvesting
- 🧩 NDJSON parsing
- 🏷️ Input-scoped processors
- 💾 Persistent registry state
- 🔄 File rotation considerations
- 🔐 Kafka SASL/PLAIN authentication
- 🛡️ Least-privilege producer access
- 🐳 Docker Compose deployment
- 📴 Air-gapped operational design

No unsupported cloud, Kubernetes, or orchestration claims are included in this component.

---

## 🔗 Related Components

```text
🛰️ Filebeat
      │
      ▼
📨 Kafka KRaft
      │
      ▼
🚚 Logstash
      │
      ▼
🔎 Elasticsearch
      │
      ▼
📊 Kibana
```

See the corresponding component READMEs for the Kafka, Logstash, Elasticsearch, and Kibana implementation details.

---

<div align="center">

### 🛰️ Filebeat → 📨 Kafka → 🚚 Logstash → 🔎 Elasticsearch → 📊 Kibana

**Fast collection. Structured events. Persistent state. Authenticated transport.**

</div>
