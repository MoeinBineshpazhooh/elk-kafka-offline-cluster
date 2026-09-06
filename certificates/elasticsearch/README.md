<div align="center">

# 🔐 Elasticsearch TLS Certificate Layer

### CA → Node Certificates → Elasticsearch → Trusted Clients

![Security](https://img.shields.io/badge/Security-TLS-blue)
![Certificates](https://img.shields.io/badge/Certificates-PKCS%2312-success)
![Deployment](https://img.shields.io/badge/Deployment-Air--gapped-orange)

</div>

---

## 🧭 Architecture at a Glance

```text
                 🔐 Local CA
                     │
          ┌──────────┼──────────┐
          ▼          ▼          ▼
        ES01       ES02       ES03
          │          │          │
          └──── TLS trust ──────┘
                     │
             ┌───────┴────────┐
             ▼                ▼
          Logstash          Kibana
          CA trust          CA trust
```

---

## 🧩 Implementation at a Glance

| Capability | Implementation |
|---|---|
| Certificate tool | `elasticsearch-certutil` |
| Node identities | ES01 / ES02 / ES03 |
| HTTP security | TLS |
| Transport security | TLS |
| Certificate format | PKCS#12 node material |
| Trust anchor | Local CA |
| Distribution | Controlled/offline transfer |
| Private keys | Outside Git |

---

## 🧠 Responsibility Boundary

This directory owns **certificate generation inputs and workflow**.

```text
instances.yml
      │
      ▼
certificate generation
      │
      ├── CA
      ├── ES01 certificate
      ├── ES02 certificate
      └── ES03 certificate
             │
             ▼
      controlled distribution
```

The runtime services consume the generated certificates; they do not generate them during normal startup.

---

## 📁 Repository Layout

```text
certificates/elasticsearch/
├── README.md
├── instances.yml
└── generate-certs.sh
```

Generated certificates and private keys are deliberately excluded from the repository.

---

## 🔑 Certificate Model

Each Elasticsearch node receives node-specific certificate material while the CA provides the trust relationship.

```text
                 Local CA
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
      ES01         ES02        ES03
  HTTP + TLS   HTTP + TLS   HTTP + TLS
  Transport    Transport    Transport
```

Clients such as Logstash and Kibana need the CA certificate when validating Elasticsearch's server certificate. The CA private key is not a client artifact.

---

## 🚀 Generation Workflow

### 1. Review identities

```text
instances.yml
```

Replace local placeholders only on the controlled deployment system.

### 2. Generate

```bash
cd certificates/elasticsearch
./generate-certs.sh
```

### 3. Verify

Confirm the expected CA and node-specific certificate material exists before transfer.

### 4. Distribute by trust requirement

```text
ES nodes     → own node certificate material
Kibana       → CA certificate
Logstash     → CA certificate
CA signing key → controlled signing system only
```

---

## 🛡️ Private-Key Handling

```text
CA private key
      │
      ├── controlled signing system
      └── ❌ never Git

Node private keys
      │
      └── protected deployment secret
```

The public repository contains generation logic, not generated private material.

---

## 🔎 Verification

Inspect a local PKCS#12 certificate:

```bash
openssl pkcs12 -info \
  -in <NODE_CERTIFICATE>.p12 \
  -noout
```

Verify the Elasticsearch HTTPS endpoint with the CA:

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/"
```

Also verify that the certificate identity matches the hostname used by the client.

---

## 🧯 Troubleshooting Flow

```text
TLS failure?
    │
    ▼
Correct CA?
    │
    ▼
Certificate identity matches endpoint?
    │
    ▼
CA mounted at expected path?
    │
    ▼
Private key / PKCS#12 readable?
    │
    ▼
Certificate not expired?
    │
    ▼
Then investigate Elasticsearch discovery/configuration
```

---

## 🧠 Operational Decisions

| Decision | Why |
|---|---|
| One controlled CA | Consistent trust model |
| Node-specific certificates | Clear node identity |
| TLS on HTTP | Protect client traffic |
| TLS on transport | Protect node-to-node traffic |
| Offline generation | Fits air-gapped operation |
| Generated material outside Git | Prevent private-key exposure |
| CA distributed by trust need | Minimize sensitive material distribution |

---

## 🧪 Practical Failure Story

When TLS fails, separate **trust**, **identity**, and **file-access** problems before changing Elasticsearch configuration:

```text
Handshake fails
     │
     ├── Trust → is the CA correct?
     ├── Identity → does SAN match the endpoint?
     └── Access → can the process read the key/certificate?
```

This is the certificate-side failure boundary used by the platform.

---

## 🔒 Portfolio Safety

No production addresses, credentials, private keys, generated certificates, or environment-specific identifiers are stored here.

---

<div align="center">

### Generate → Verify → Distribute → Trust

**Controlled. Node-specific. TLS-protected. Air-gapped ready.**

</div>
