<div align="center">

# 🖥️ Kafka Administration UIs

### Optional Operational Interfaces for the Kafka Layer

**AKHQ · Kafka UI · Docker Compose · Air-Gapped Friendly**

</div>

---

## 🧭 Purpose

This directory contains optional web interfaces used to inspect and operate the Kafka layer during development and operations.

They are intentionally kept separate from the Kafka brokers themselves. The UI host connects to the Kafka listener and provides a browser-based view of topics, partitions, consumer groups, messages, and cluster metadata.

```text
                    Kafka KRaft Cluster
                           │
                    SASL/PLAIN listener
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
        ┌───────────┐             ┌───────────┐
        │   AKHQ    │             │  Kafka UI │
        │ optional  │             │ optional  │
        └───────────┘             └───────────┘
              │                         │
              └────────────┬────────────┘
                           ▼
                    Operations / Debugging
```

> **Portfolio-safe example:** broker addresses, credentials, and environment-specific values must be replaced locally and are not stored in Git.

---

## 🎯 What This Implements

- optional AKHQ deployment
- optional Kafka UI deployment
- Docker Compose
- host networking
- configurable Kafka bootstrap servers
- a structure suitable for secured Kafka deployments
- isolated operational tooling that does not modify the broker configuration

The UIs are not required for the Filebeat → Kafka → Logstash data path. They are operational interfaces for inspection and troubleshooting.

---

## 📁 Repository Layout

```text
ui/
├── README.md
└── docker-compose.akhq-kafka-ui.yml
```

The Compose file contains both optional services so the tools can be started together when required.

---

## 🔐 Kafka Connectivity

The example is designed around the same Kafka security model used by the platform: authenticated Kafka clients using SASL/PLAIN.

For a secured deployment, configure the UI with the appropriate Kafka client properties rather than embedding credentials in the Compose file.

Conceptually:

```text
UI
 │
 │ bootstrap servers
 │ SASL mechanism
 │ credentials
 ▼
Kafka listener
```

If TLS is enabled for the Kafka listener, the corresponding trust configuration must also be supplied to the UI client.

> `SASL_PLAINTEXT` authenticates clients but does not encrypt traffic. Use the TLS-enabled Kafka listener when confidentiality is required.

---

## 🚀 Deployment

### 1. Prepare the local configuration

Copy or adapt the Compose configuration locally and set the Kafka bootstrap endpoints required by the deployment.

Do not commit real broker addresses, passwords, certificates, or private keys.

### 2. Start the UIs

```bash
cd ui
docker compose -f docker-compose.akhq-kafka-ui.yml up -d
```

### 3. Check service logs

```bash
docker logs -f akhq
docker logs -f kafka-ui
```

### 4. Check running containers

```bash
docker ps --filter name=akhq
docker ps --filter name=kafka-ui
```

---

## 🔎 Operational Use

These interfaces are useful for validating the Kafka layer independently from the rest of the ingestion pipeline.

### Topic inspection

Use the UI to verify:

- expected topics exist
- partition counts are correct
- replication is present
- messages are arriving
- timestamps and payloads look correct

### Consumer-group inspection

For the Logstash consumer group, inspect:

- group state
- assigned partitions
- current offsets
- consumer lag
- active consumers

This is particularly useful when the application is producing events but downstream Elasticsearch documents are not increasing.

### Authentication troubleshooting

When a client cannot connect, compare the UI's Kafka client configuration with the broker listener configuration:

```text
Bootstrap servers
       │
       ▼
Security protocol
       │
       ▼
SASL mechanism
       │
       ▼
Username / credential
       │
       ▼
Authorization / ACL
```

Authentication and authorization are separate checks. A successfully authenticated identity can still be denied by Kafka ACLs.

---

## 🧯 Troubleshooting Flow

```text
                  UI cannot connect?
                         │
                         ▼
               Kafka listener reachable?
                    │            │
                   NO           YES
                    │            │
                    ▼            ▼
             Check network   Authentication
                                  │
                         ┌────────┴────────┐
                        FAIL              PASS
                         │                  │
                         ▼                  ▼
                    SASL config         ACL check
                                            │
                                            ▼
                                      Topic / group
```

### UI starts but shows no topics

Check:

1. bootstrap server configuration;
2. security protocol and SASL mechanism;
3. credentials;
4. cluster authorization;
5. topic-level permissions.

### Topics are visible but messages cannot be inspected

Check whether the UI identity has the required read/describe permissions for the topic and consumer-group operations.

### Consumer lag looks incorrect

Compare the UI view with the Kafka consumer-group state and verify that the expected Logstash consumers are actually running.

---

## 🧠 Operational Decisions

| Decision | Implementation |
|---|---|
| Role | Optional Kafka administration and inspection |
| Deployment | Docker Compose |
| Network model | Host networking |
| Authentication | Compatible with SASL/PLAIN Kafka |
| TLS | Supported when configured on the Kafka listener |
| Data path dependency | None; operational tooling only |
| Secret handling | Keep credentials outside Git |
| Air-gapped operation | Images can be preloaded before deployment |

---

## 🔒 Portfolio Safety

This directory intentionally contains no production connection details.

Never commit:

- real broker IP addresses or hostnames
- Kafka passwords
- TLS private keys
- environment-specific registry names
- production topic or infrastructure identifiers

Use generic placeholders in documentation and provide deployment-specific values locally.

---

<div align="center">

### Inspect → Authenticate → Authorize → Observe

**Operational visibility for the Kafka layer without coupling it to the data path.**

</div>
