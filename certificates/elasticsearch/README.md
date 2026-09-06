<div align="center">

# 🔐 Elasticsearch TLS Certificates

### Certificate Workflow for HTTP and Transport Security

**CA → Node Certificates → Elasticsearch → Kibana / Logstash Trust**

</div>

---

## 🧭 Purpose

This directory contains the certificate-generation workflow for the Elasticsearch cluster.

The goal is to establish two independent TLS trust paths:

```text
Client traffic
─────────────
Logstash / Kibana / Admin Client
             │
             │ HTTPS + TLS
             ▼
      Elasticsearch HTTP

Node traffic
────────────
ES01 ◄──── TLS ────► ES02
 │                    │
 └──────── TLS ──────► ES03
```

The repository stores the generation inputs and scripts only. Generated certificates and private keys remain outside Git.

---

## 🎯 What Is Generated

The workflow uses `elasticsearch-certutil` to create:

- a local certificate authority (CA)
- node transport certificates
- node HTTP certificates
- certificate material suitable for the Elasticsearch nodes

The CA certificate can also be distributed to trusted clients such as Kibana and Logstash.

The CA private key must remain protected on the certificate-generation system.

---

## 📁 Files

```text
certificates/elasticsearch/
├── README.md
├── instances.yml
└── generate-certs.sh
```

### `instances.yml`

Defines the certificate identities for the Elasticsearch nodes. Public values are placeholders and must be replaced locally.

### `generate-certs.sh`

Runs the certificate-generation workflow using the pinned Elasticsearch image/tooling.

### Generated output

The script creates generated material locally. That output is intentionally not part of the public repository.

---

## 🔑 Certificate Model

Each Elasticsearch node needs certificate identities appropriate for the names clients and peer nodes use to reach it.

```text
                Local CA
                   │
        ┌──────────┼──────────┐
        ▼          ▼          ▼
      ES01       ES02       ES03
   HTTP + TLS  HTTP + TLS  HTTP + TLS
   Transport  Transport   Transport
```

The same CA establishes the trust relationship, while each node receives its own certificate material.

---

## 🚀 Generation Workflow

Certificate generation should be performed on a controlled system before the air-gapped deployment.

### 1. Prepare the identities

Review:

```text
instances.yml
```

Replace only the local placeholders required by the target deployment. Do not commit those values back to Git.

### 2. Generate certificates

```bash
cd certificates/elasticsearch
./generate-certs.sh
```

### 3. Inspect the generated output

Confirm that the expected CA and node-specific certificate files were created before distribution.

### 4. Distribute by trust requirement

The Elasticsearch nodes receive their own node certificate material.

Kibana and Logstash normally need the CA certificate to validate Elasticsearch's server certificate.

Do not distribute the CA private key to application or observability nodes.

---

## 🛡️ Private-Key Handling

The most sensitive artifact in this workflow is the CA private key.

```text
CA private key
     │
     ├── keep on controlled signing system
     └── never commit to Git
```

Node private keys are also deployment secrets and must be protected with filesystem permissions and appropriate operational controls.

The public repository contains no generated private material.

---

## 🔎 Verification

Before starting Elasticsearch, verify the certificate files exist at the local paths expected by the Compose configuration.

For certificate inspection, use OpenSSL locally:

```bash
openssl pkcs12 -info \
  -in <NODE_CERTIFICATE>.p12 \
  -noout
```

Validate the certificate identity and CA chain according to the hostname/address used by the deployment.

After Elasticsearch starts, verify the HTTPS endpoint using the CA certificate:

```bash
curl --cacert /path/to/ca.crt \
  -u elastic:<PASSWORD> \
  "https://<ELASTICSEARCH_HOST>:9200/"
```

---

## 🧯 Troubleshooting

### Certificate verification fails

Check:

1. the CA used by the client matches the CA that signed the Elasticsearch certificate;
2. the certificate contains the hostname/IP identity used by the client;
3. the correct CA path is mounted into the container;
4. the certificate has not expired.

### Elasticsearch cannot load a PKCS#12 file

Check:

1. the file is readable by Elasticsearch;
2. the configured keystore password matches the generated certificate;
3. the file was not corrupted during transfer;
4. the certificate contains the expected key material.

### Node-to-node TLS fails

Check each node's transport certificate, trust configuration, and certificate identity before investigating discovery or cluster formation.

---

## 🌐 Air-Gapped Workflow

The certificate workflow fits the offline deployment model:

```text
Connected / controlled system
          │
          ├── generate certificates
          ├── verify certificate chain
          │
          ▼
     Controlled transfer
          │
          ▼
     Air-gapped hosts
          │
          ├── ES node certificates
          └── CA certificate for trusted clients
```

Certificate generation itself does not require runtime internet access when the required Elasticsearch image/tooling has already been staged locally.

---

## 🔒 Portfolio Safety

This directory intentionally contains no real infrastructure identities, addresses, passwords, or private keys.

Replace placeholders only on the controlled deployment system and keep generated material outside the repository.

---

<div align="center">

### Generate → Verify → Distribute → Trust

**One controlled CA. Node-specific identities. Encrypted Elasticsearch communication.**

</div>
