# Filebeat — Isolated Filestream Ingestion

Filebeat is the edge ingestion layer in this portfolio architecture. It watches application log files with the `filestream` input, parses structured JSON lines, applies input-scoped processors, and publishes events to Kafka using SASL/PLAIN.

> **Portfolio-safe example:** all hosts, topics, paths, principals, and credentials in this directory are fictional placeholders.

## Architecture

```text
+----------------------+       +-------------------------+
| Demo Application     |       | Filebeat                |
| JSON log files       +------>+ filestream              |
| /var/log/demo-app/   |       | input-scoped processors |
+----------------------+       +------------+------------+
                                            |
                                            | SASL/PLAIN
                                            v
                               +-------------------------+
                               | Kafka KRaft cluster     |
                               | demo-application-logs   |
                               +------------+------------+
                                            |
                                            v
                               +-------------------------+
                               | Logstash                |
                               | Kafka -> Elasticsearch  |
                               +-------------------------+
```

## Design goals

- **Filestream-first ingestion** for reliable file tracking.
- **Fast file discovery** with a 1-second scanner interval.
- **Large harvester buffer** for higher-throughput structured logs.
- **Short backoff** to reduce recovery latency when files are temporarily unavailable.
- **Isolated input configuration** so additional log sources can be added without turning one file into a monolithic configuration.
- **Persistent Filebeat registry** so container restarts do not discard file state.
- **Kafka authentication** with SASL/PLAIN.
- **Air-gapped friendly deployment** using a pinned container image that can be preloaded into a private registry.

## Repository layout

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

### Why the input is separated

`config/filebeat.yml` contains the shared Filebeat runtime and Kafka output. Individual sources live under `inputs/` and are loaded through Filebeat's input configuration loader.

That separation makes it straightforward to add another source later:

```text
inputs/
├── demo-application-logs.yml
├── demo-platform-events.yml
└── demo-audit-events.yml
```

Each input can own its paths, parsers, and processors while the output/security configuration remains centralized.

## Filestream tuning

The example keeps the operational tuning explicit:

| Setting | Example | Purpose |
|---|---:|---|
| `check_interval` | `1s` | Detect newly created/changed files quickly |
| `harvester_limit` | `0` | No artificial harvester cap |
| `harvester_buffer_size` | `4 MiB` | Larger read buffer for busy log files |
| `backoff.init` | `100ms` | Fast retry after a temporary read issue |
| `backoff.max` | `1s` | Keeps recovery latency bounded |
| registry volume | persistent | Preserves offsets/state across restarts |

## Structured log parsing

The demo input expects newline-delimited JSON. The NDJSON parser writes decoded fields directly into the event and records parsing failures instead of silently dropping malformed records.

Processors are deliberately attached to the individual input. This keeps source-specific enrichment isolated and avoids accidentally applying application metadata to unrelated inputs.

## Kafka security

The example publishes to Kafka with:

- `SASL_PLAINTEXT`
- `PLAIN` mechanism
- dedicated `filebeat` principal
- a single fictional application-log topic
- credentials supplied through an environment file rather than committed configuration

`SASL_PLAINTEXT` authenticates the client but **does not encrypt Kafka traffic**. For production environments where confidentiality is required, use the appropriate TLS-enabled Kafka listener and configure the corresponding CA/certificate settings.

## Deployment

1. Copy the example environment file locally:

```bash
cp env/filebeat.env.example env/filebeat.env
```

2. Replace only the local placeholder values. Do not commit `env/filebeat.env`.

3. Make the application log directory available to the container:

```text
/var/log/demo-app/
```

4. Start Filebeat:

```bash
docker compose -f filebeat/docker-compose.filebeat01.yml up -d
```

For an air-gapped environment, preload the pinned Filebeat image into the local/private registry before starting the service.

## Verification

Check the container:

```bash
docker ps --filter name=filebeat01
```

Follow Filebeat logs:

```bash
docker logs -f filebeat01
```

Validate the configuration before deployment:

```bash
docker run --rm \
  -v "$PWD/filebeat/config/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro" \
  -v "$PWD/filebeat/inputs:/usr/share/filebeat/inputs:ro" \
  docker.elastic.co/beats/filebeat:9.0.1 \
  filebeat test config -e
```

Generate a small JSON test record in the mounted demo directory and verify that the Kafka topic receives the event.

## Operational considerations

### File rotation

`filestream` is preferred for environments where application files are frequently rotated or renamed. The persistent registry is important because it allows Filebeat to retain file identity and offsets across restarts.

### Permissions

The container runs as `root` in this example so that the edge collector can read files with restrictive host ownership/permissions. A production deployment should instead use the least-privileged identity that can reliably read the required log paths.

### Registry persistence

Do not mount the Filebeat data directory as an ephemeral container filesystem in production. Losing the registry can cause files to be re-read or state to be reconstructed unexpectedly.

### Backpressure

Kafka is the downstream buffer. If Kafka becomes unavailable, monitor Filebeat output errors and event queue behavior rather than assuming that the application log directory itself provides unlimited buffering.

## Troubleshooting

### Filebeat starts but does not discover files

Check the mounted path inside the container:

```bash
docker exec filebeat01 sh -c 'ls -lah /var/log/demo-app/'
```

Then verify the input path and permissions.

### Filebeat discovers the file but cannot read it

Check ownership and mode on the host and inside the container. A file becoming unreadable after rotation is a common cause of apparently stalled harvesting.

### Kafka authentication fails

Verify the bootstrap addresses, topic, username, password, SASL mechanism, and listener protocol in the local environment file. The committed example intentionally contains no real credentials.

### Events are duplicated after restart

Inspect the persistent `filebeat-data` volume and confirm that the registry survives container recreation.

## Security notes

- Never commit the real environment file.
- Never commit Kafka passwords, certificates, private keys, or tokens.
- Keep Filebeat's Kafka principal limited to the topics it actually needs.
- Use TLS when Kafka traffic crosses an untrusted network.
- Treat the example addresses and topic names as documentation-only values.

## Related components

The intended flow is:

```text
Application files
      |
      v
   Filebeat
      |
      | SASL/PLAIN
      v
 Kafka KRaft
      |
      v
  Logstash
      |
      | TLS
      v
Elasticsearch
```
