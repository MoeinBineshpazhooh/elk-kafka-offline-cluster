# Filebeat — Edge Log Ingestion

Filebeat is the edge collection layer of this observability platform.

It runs close to the applications, discovers log files with `filestream`, parses newline-delimited JSON, enriches events at the input level, and publishes them to Kafka. Kafka then provides the durable transport boundary between edge collection and downstream processing.

This directory represents the implemented Filebeat design: isolated inputs, persistent registry state, high-frequency file discovery, structured parsing, Kafka authentication, and containerized deployment for air-gapped environments.

---

## Architecture

```text
Application
    |
    | JSON log files
    v
+-----------+
| Filebeat  |
| filestream|
+-----+-----+
      |
      | SASL/PLAIN
      v
+-------------+
| Kafka KRaft |
+------+------+ 
       |
       v
   Logstash
       |
       v
 Elasticsearch
```

The boundary is intentional:

- Filebeat owns **file discovery, reading, parsing and source enrichment**.
- Kafka owns **transport and buffering between collection and processing**.
- Logstash owns **downstream processing and Elasticsearch delivery**.

Filebeat does not contain Elasticsearch output configuration because that responsibility belongs to the downstream processing layer.

---

## Implementation at a Glance

| Area | Implementation |
|---|---|
| Version | Filebeat 9.0.1 |
| Input | `filestream` |
| Log format | NDJSON / JSON Lines |
| Input isolation | One configuration file per source |
| File discovery | 1 second scanner interval |
| Harvester limit | Unlimited (`0`) |
| Read buffer | 4 MiB |
| Initial backoff | 100 ms |
| Maximum backoff | 1 second |
| State | Persistent Filebeat registry |
| Output | Kafka |
| Kafka authentication | SASL/PLAIN |
| Kafka protocol | `SASL_PLAINTEXT` example |
| Deployment | Docker Compose |
| Target environment | Air-gapped / offline capable |

---

## Why `filestream`?

The implementation uses `filestream` rather than treating log files as static inputs.

This matters in environments where applications continuously create, append to, rotate, rename, and replace files. Filebeat needs to maintain file identity and offsets while the filesystem changes around it.

The design therefore combines:

1. `filestream` for file lifecycle handling.
2. A persistent registry for offsets and file state.
3. Short discovery and retry intervals for fast reaction to new data.
4. Explicit input-level processors so source-specific metadata stays isolated.

---

## Configuration Isolation

The configuration is deliberately split into two layers.

```text
filebeat/config/filebeat.yml
        |
        | shared runtime + output
        v
filebeat/inputs/*.yml
        |
        | source-specific paths
        | parsers
        | processors
        v
     Events
```

`config/filebeat.yml` contains the shared runtime and Kafka output configuration.

Individual log sources live under `inputs/` and are loaded through Filebeat's configuration loader.

Current example:

```text
inputs/
└── demo-application-logs.yml
```

A new source can be added independently without turning the main Filebeat configuration into a large monolithic file.

For example:

```text
inputs/
├── demo-application-logs.yml
├── demo-platform-events.yml
└── demo-audit-events.yml
```

The filenames above are portfolio examples only.

---

## Input Processing Pipeline

The implemented input follows this sequence:

```text
Log file
   |
   v
filestream discovery
   |
   v
File harvester
   |
   v
NDJSON parser
   |
   v
Input-scoped processors
   |
   v
Kafka output
```

### NDJSON parsing

The example input uses the NDJSON parser with decoded fields written into the event.

Malformed records are retained with an error field rather than being silently discarded. This makes parsing problems visible during operational investigation.

### Input-scoped processors

Processors are attached to the individual input rather than placed globally.

That is an important design choice when several applications share the same Filebeat instance: metadata belonging to one source should not accidentally appear on another source.

---

## Filestream Performance Tuning

The example includes explicit tuning for environments where log files are generated frequently.

| Setting | Value | Reason |
|---|---:|---|
| `prospector.scanner.check_interval` | `1s` | Discover new or changed files quickly |
| `harvester_limit` | `0` | Avoid an artificial global harvester ceiling |
| `harvester_buffer_size` | `4194304` | Provide a larger read buffer for busy files |
| `backoff.init` | `100ms` | Recover quickly from temporary read conditions |
| `backoff.max` | `1s` | Bound retry delay |

These settings are operational choices, not universal defaults. They should be adjusted according to file volume, event size, storage performance, and available resources.

---

## File Rotation and Registry State

File rotation is one of the important operational concerns for this layer.

A typical lifecycle is:

```text
Application writes
       |
       v
 active.log
       |
       | rotation / rename
       v
 archived file
       |
       v
 new active.log
```

Filebeat must distinguish the files correctly and retain the appropriate read position.

The registry therefore needs persistent storage. If the registry disappears when the container is recreated, Filebeat may need to reconstruct file state and can potentially reread data.

The Docker deployment mounts the Filebeat data directory as persistent storage for this reason.

---

## Permissions and Container Boundaries

A file being visible on the host does not automatically mean that Filebeat can read it inside the container.

The complete access path is:

```text
Host filesystem
      |
      | bind mount
      v
Container filesystem
      |
      | Unix permissions / ownership
      v
Filebeat process
```

When a log file is rotated, its ownership or mode can also change. A previously readable file can therefore become unreadable without any Filebeat configuration change.

When investigating a harvesting problem, verify both:

```bash
ls -lah /var/log/demo-app/
```

and from inside the container:

```bash
docker exec filebeat01 sh -c 'ls -lah /var/log/demo-app/'
```

This distinction is especially important when the application and Filebeat run with different Unix identities.

---

## Kafka Output

Filebeat publishes events to Kafka rather than directly to Elasticsearch.

```text
Filebeat
   |
   | authenticated producer
   v
Kafka topic
   |
   v
Logstash consumer group
```

The example uses:

- SASL authentication
- PLAIN mechanism
- a dedicated Filebeat Kafka identity
- an explicitly configured topic
- credentials supplied through the local environment

The example uses `SASL_PLAINTEXT`. This provides authentication but **does not provide encryption in transit**. If the Kafka network is not trusted, use a TLS-enabled listener and configure the corresponding Filebeat TLS settings.

The Filebeat producer configuration is intentionally separate from Elasticsearch delivery. This keeps the edge collector independent of the storage and processing layer.

---

## Deployment Model

The component is containerized with Docker Compose and designed so the runtime values remain outside the public repository.

```text
env/filebeat.env.example
          |
          | local values
          v
   docker-compose
          |
          v
      Filebeat
          |
          v
       Kafka
```

Create the local environment file:

```bash
cp env/filebeat.env.example env/filebeat.env
```

Replace the placeholders locally. Do not commit the resulting environment file.

Start the example deployment:

```bash
docker compose -f filebeat/docker-compose.filebeat01.yml up -d
```

In an air-gapped environment, the required Filebeat image should be available locally or in the organization's private registry before deployment.

---

## Repository Layout

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

The separation reflects the deployment model rather than being only a documentation convention.

---

## Verification

### 1. Check the container

```bash
docker ps --filter name=filebeat01
```

### 2. Inspect runtime logs

```bash
docker logs --tail 200 filebeat01
```

### 3. Validate the configuration

```bash
docker run --rm \
  -v "$PWD/filebeat/config/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro" \
  -v "$PWD/filebeat/inputs:/usr/share/filebeat/inputs:ro" \
  docker.elastic.co/beats/filebeat:9.0.1 \
  filebeat test config -e
```

### 4. Verify file visibility

```bash
docker exec filebeat01 sh -c 'ls -lah /var/log/demo-app/'
```

### 5. Verify the transport path

After writing a test JSON record to the mounted application directory, verify that Filebeat reports successful publishing and that the configured Kafka topic receives the event.

The complete verification path is:

```text
file exists
    |
    v
Filebeat discovers it
    |
    v
Filebeat parses it
    |
    v
Kafka accepts it
    |
    v
Logstash consumes it
    |
    v
Elasticsearch stores it
```

---

## Troubleshooting Guide

### File exists but Filebeat does not discover it

Check:

1. the path inside the container;
2. the `filestream` configuration;
3. whether the input file is enabled;
4. Filebeat logs for scanner errors;
5. whether the file is actually covered by the configured glob.

### File is discovered but cannot be harvested

Check ownership and permissions on both sides of the container boundary.

A particularly important case is file rotation: the application may create the replacement file with different permissions from the original.

### Registry appears empty or state is lost

Check that the Filebeat data directory is backed by persistent storage and that the container is not recreating an empty volume.

### Events appear duplicated after restart

Investigate registry persistence first. Losing file state can cause Filebeat to reconsider files whose offsets were previously known.

### Kafka authentication fails

Check the local Kafka connection contract:

```text
bootstrap servers
username
password
SASL mechanism
security protocol
topic
```

Do not place real credentials into the repository while troubleshooting.

### Kafka is unavailable

Monitor Filebeat output errors and the resulting event backlog. Kafka is the downstream transport boundary, but Filebeat should not be treated as an unlimited persistent queue.

---

## Security Model

The Filebeat security model follows least privilege at the Kafka boundary.

```text
Filebeat
   |
   | dedicated identity
   | SASL authentication
   v
Kafka
   |
   | topic-level authorization
   v
Application-log stream
```

Security rules for the public example:

- credentials are supplied outside Git;
- no private keys are stored in this directory;
- the Filebeat Kafka identity should only have the permissions required for publishing;
- use TLS when Kafka traffic requires confidentiality;
- keep host filesystem access limited to the log directories Filebeat actually needs.

---

## Operational Decisions

| Decision | Why |
|---|---|
| `filestream` | Better fit for actively changing and rotated log files |
| Isolated input files | Keeps source-specific behavior maintainable |
| Input-scoped processors | Prevents cross-source metadata contamination |
| NDJSON parser | Handles structured application log records directly |
| 1-second discovery | Reduces detection latency for newly generated files |
| 4 MiB harvester buffer | Supports higher-volume file reads |
| Short backoff | Reduces recovery latency |
| Persistent registry | Preserves file identity and offsets across restarts |
| Kafka output | Decouples edge collection from downstream processing |
| SASL/PLAIN | Provides authenticated Kafka access in the example deployment |
| External environment file | Keeps credentials and deployment values out of Git |
| Docker Compose | Matches the implemented host-based deployment model |

---

## Air-Gapped Deployment Considerations

The component does not depend on internet access during normal runtime.

For an offline deployment, prepare the Filebeat image and required configuration artifacts before deployment:

```text
Offline preparation
        |
        v
Container image + configuration
        |
        v
Private/local image source
        |
        v
Filebeat host
        |
        v
Kafka cluster
```

The repository therefore stores configuration templates and deployment definitions, while environment-specific values and private artifacts remain outside Git.

---

## Portfolio Scope

This component intentionally demonstrates the parts of Filebeat that are actually used by the platform:

- edge file collection;
- filestream-based ingestion;
- structured JSON parsing;
- source-specific processors;
- persistent registry handling;
- file rotation considerations;
- Kafka authentication;
- Docker-based deployment;
- air-gapped operational design;
- troubleshooting of real ingestion failure modes.

It does not claim integrations or orchestration platforms that are outside this implementation.

---

## Related Components

```text
Filebeat
   |
   v
Kafka KRaft
   |
   v
Logstash
   |
   v
Elasticsearch
   |
   v
Kibana
```

See the component READMEs for the corresponding Kafka, Logstash, Elasticsearch, and Kibana implementation details.

---

**Filebeat 9.0.1 — edge collection, structured parsing, authenticated transport, and operationally persistent state.**
