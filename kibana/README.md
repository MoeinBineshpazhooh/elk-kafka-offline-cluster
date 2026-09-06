<div align="center">

# 📊 Kibana

### Operational Visualization Layer for the Observability Platform

**Kibana 9.2.4 · Elasticsearch HTTPS · Saved Objects · Data Views · Docker Compose**

</div>

---

## 🧭 Role in the Platform

Kibana is the presentation and investigation layer of the platform. It connects to the secured Elasticsearch cluster, provides operational search and visualization, and hosts the saved dashboard objects used by the portfolio example.

```text
Filebeat
    │
    ▼
Kafka KRaft
    │
    ▼
Logstash
    │ HTTPS
    ▼
Elasticsearch
    │ HTTPS
    ▼
┌──────────────────────────┐
│         Kibana            │
│                          │
│  Data Views              │
│  Dashboards              │
│  Visualizations          │
│  Saved Objects            │
└──────────────────────────┘
```

The repository intentionally keeps Kibana focused on the implemented observability workflow rather than adding unrelated plugins or services.

---

## 🎯 What This Implements

- Kibana `9.2.4`
- two example Kibana nodes
- Docker Compose deployment per host
- host networking
- connection to Elasticsearch over HTTPS
- CA-based Elasticsearch certificate validation
- Kibana security encryption keys supplied through environment configuration
- HTTP serving mode for simple internal deployments
- HTTPS serving mode for encrypted client-to-Kibana traffic
- portable Saved Objects bundle
- portfolio-safe Data View and dashboard definitions

---

## 🏗️ Deployment Model

Each Kibana host has its own Compose file. The node-specific files intentionally remain small because environment-specific endpoints, credentials, and encryption keys are supplied through `env/kibana.env`.

```text
kibana/
├── docker-compose.kibana01.yml
├── docker-compose.kibana01.https.yml
├── docker-compose.kibana02.yml
├── docker-compose.kibana02.https.yml
├── saved-objects.ndjson
├── saved-objects/
│   └── README.md
└── README.md
```

The HTTP and HTTPS Compose variants share the same Elasticsearch connection model. The difference is whether Kibana itself terminates TLS.

---

## 🔐 Security Model

### Kibana → Elasticsearch

The Kibana service connects to Elasticsearch using HTTPS and a mounted CA certificate:

```text
Kibana
  │
  │ HTTPS
  │ CA validation
  ▼
Elasticsearch :9200
```

The connection uses the `kibana_system` service identity. The password is supplied outside Git through the local environment file.

### Client → Kibana

Two deployment variants are available:

| Mode | Client connection | Use |
|---|---|---|
| HTTP | `http://<KIBANA_HOST>:5601` | Internal/trusted network example |
| HTTPS | `https://<KIBANA_HOST>:5601` | Encrypted client-to-Kibana traffic |

The HTTPS variant mounts a Kibana server certificate and private key read-only into the container.

### Encryption keys

The Compose configuration supplies three persistent Kibana encryption keys:

- `XPACK_SECURITY_ENCRYPTIONKEY`
- `XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY`
- `XPACK_REPORTING_ENCRYPTIONKEY`

These values must remain stable for the lifetime of the deployment and must never be committed to the repository.

---

## 📜 Certificates

Kibana needs the Elasticsearch CA even when Kibana itself is served over HTTP.

Elasticsearch CA inside the container:

```text
/usr/share/kibana/config/certs/ca/ca.crt
```

HTTPS mode additionally requires:

```text
/usr/share/kibana/config/certs/server/kibana.crt
/usr/share/kibana/config/certs/server/kibana.key
```

Certificates are generated and managed separately from the Kibana deployment. See the repository certificate workflow rather than storing generated private material in Git.

---

## ⚙️ Configuration

Create the local environment file from the committed example:

```bash
cp env/kibana.env.example env/kibana.env
```

The example defines the expected configuration contract:

```text
KIBANA_VERSION=9.2.4
KIBANA_SERVER_HOST=0.0.0.0
KIBANA_SERVER_PORT=5601
ELASTICSEARCH_HOSTS=["https://<ES_NODE_1_HOST>:9200", "https://<ES_NODE_2_HOST>:9200", "https://<ES_NODE_3_HOST>:9200"]
```

Replace placeholders locally. Do not commit `env/kibana.env`.

---

## 🚀 Deployment

### HTTP mode

```bash
cd kibana
docker compose -f docker-compose.kibana01.yml up -d
docker logs -f kibana01
```

Repeat with the corresponding Compose file on the second Kibana host.

### HTTPS mode

```bash
cd kibana
docker compose -f docker-compose.kibana01.https.yml up -d
docker logs -f kibana01
```

Use the HTTPS variant only after the Kibana server certificate and key have been placed at the paths expected by the Compose file.

---

## 📊 Saved Objects & Dashboard

The repository contains a portable NDJSON bundle at:

```text
kibana/saved-objects.ndjson
```

The bundle contains:

- one Data View for `demo-logs-*`
- `@timestamp` as the time field
- event-volume visualization
- events-by-service visualization
- log-level distribution visualization
- an operational dashboard combining those visualizations

Import through **Stack Management → Saved Objects**, or use the Saved Objects API:

```bash
curl --fail --silent --show-error \
  -X POST "${KIBANA_URL}/api/saved_objects/_import?overwrite=true" \
  -H 'kbn-xsrf: true' \
  -H 'Content-Type: application/ndjson' \
  --data-binary @kibana/saved-objects.ndjson
```

Detailed import and versioning notes are documented in `saved-objects/README.md`.

---

## 🔎 Verification

Check the Kibana container:

```bash
docker ps --filter name=kibana01
docker logs --tail 200 kibana01
```

Check Kibana status:

```bash
curl --fail \
  "http://<KIBANA_HOST>:5601/api/status"
```

For HTTPS mode, use the equivalent HTTPS endpoint and the appropriate CA trust configuration.

A healthy deployment should show Kibana reaching its available state and successfully connecting to Elasticsearch.

---

## 🧯 Troubleshooting Flow

```text
                 Kibana unavailable?
                         │
                         ▼
                 Check container logs
                         │
             ┌───────────┴───────────┐
             │                       │
        Elasticsearch           Kibana server
          connection               startup
             │                       │
             ▼                       ▼
      Check HTTPS / CA       Check cert/key paths
             │                       │
             ▼                       ▼
     Check credentials       Check encryption keys
             │                       │
             └───────────┬───────────┘
                         ▼
                 Check /api/status
                         │
                         ▼
                 Import Saved Objects
                         │
                         ▼
                  Verify Data View
```

### Elasticsearch connection errors

Check:

1. Elasticsearch is reachable.
2. `ELASTICSEARCH_HOSTS` points to the intended HTTPS endpoints.
3. The CA file is mounted at the expected path.
4. The `kibana_system` credentials are correct.
5. TLS verification mode matches the certificate deployment.

### HTTPS startup errors

Check:

1. the server certificate exists;
2. the private key exists;
3. both files are readable by Kibana;
4. the certificate identity matches the hostname clients use.

### Dashboard shows no data

The dashboard depends on the Data View and fields present in the incoming documents. Verify that:

```text
@timestamp
service.source
log.level
message
```

exist where required by the imported visualizations. If the target mapping differs, export compatible Saved Objects from that deployment instead of editing generated migration metadata by hand.

---

## 🧠 Operational Decisions

| Decision | Implementation |
|---|---|
| Kibana version | `9.2.4` |
| Deployment | Docker Compose per host |
| Network model | Host networking |
| Elasticsearch connection | HTTPS |
| CA trust | Mounted Elasticsearch CA |
| Client access | HTTP and HTTPS variants |
| Encryption keys | Environment-supplied and persistent |
| Dashboard portability | NDJSON Saved Objects |
| Data View | `demo-logs-*` |
| Time field | `@timestamp` |
| Secret handling | Local environment file, not Git |
| Air-gapped operation | Preloaded image/artifacts; no runtime registry dependency |

---

## 🔒 Portfolio Safety

All environment-specific values remain outside the public configuration:

- no production IP addresses
- no production hostnames
- no passwords or tokens
- no private keys
- no environment-specific registry names

Use the placeholders exactly as documentation contracts and replace them only in the local deployment environment.

---

## 📚 Related Files

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

<div align="center">

### Elasticsearch HTTPS → Kibana → Data Views → Operational Dashboards

**Secure visualization. Portable objects. Clear operational workflows.**

</div>
