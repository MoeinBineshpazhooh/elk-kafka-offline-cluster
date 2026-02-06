# ELK + Kafka Offline Cluster (Air-Gapped Deployment)

[![License](https://img.shields.io/github/license/MoeinBineshpazhooh/elk-kafka-offline-cluster)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Essential-blue.svg)](https://www.docker.com/)
[![Elastic 9.2.4](https://img.shields.io/badge/Elastic-9.2.4-green.svg)](https://www.elastic.co/)
[![Kafka Latest](https://img.shields.io/badge/Kafka-latest-orange.svg)](https://kafka.apache.org/)

Complete offline deployment of production-ready ELK Stack + Kafka KRaft cluster across 10 servers.

Supports fully air-gapped environments with offline Docker installation, pre-built image bundles, and automated certificate generation.

## 🎯 Features

- **Fully Offline**: Docker + all container images bundled (no internet required)
- **Elasticsearch 9.2.4**: 3-node cluster with TLS (HTTP + Transport), security enabled
- **Kafka KRaft**: 3 controllers + 2 brokers (no ZooKeeper)
- **Logstash**: Kafka to Elasticsearch pipelines with TLS authentication
- **Kibana**: Multi-node dashboard with SSL and security
- **UIs**: AKHQ + Kafka-UI for Kafka management
- **Certificates**: Automated TLS certificate generation for Elasticsearch
- **Production-ready**: Proper node roles, service discovery, health checks

## 🖥️ Architecture (10 Nodes)

**Elasticsearch Cluster (3 nodes)**:
- es01, es02, es03: All master-eligible + data + ingest (with TLS, security enabled)

**Kibana + Logstash (2 nodes)**:
- kibana01, kibana02 (Kibana UI with SSL)
- logstash01, logstash02 (Kafka to Elasticsearch pipelines)

**Kafka KRaft (5 nodes)**:
- kafka-controller01, kafka-controller02, kafka-controller03 (KRaft quorum)
- kafka-broker01, kafka-broker02 (data brokers)

**UIs (1 node)**:
- akhq-ui + kafka-ui (combined)

See [docs/host-layout-example.md](docs/host-layout-example.md) for detailed topology.

## 🚀 Quick Start (Air-Gapped Environment)

### Prerequisites

- Ubuntu 22.04 or later on 10 Linux servers
- SSH access between servers
- Offline media (USB drive) with Docker packages + image bundle (~15GB total)
- Basic familiarity with Docker and docker-compose

### Step 1: Prepare Offline Packages

On a machine with **internet access**:

```
cd offline/docker
./download-docker.sh
```
```
cd ../images
./download-images.sh
```
# Creates: elk-kafka-images.tar (~10GB)
Copy the following to USB or offline media:

Docker .deb packages (from offline/docker/packages/)

offline/images/elk-kafka-images.tar

### Step 2: Install Docker on Each Server (Offline)
On each of the 10 servers in air-gapped network:

```
cd offline/docker
./install-docker-offline.sh
docker --version
docker compose version
```

### Step 3: Load Container Images
On each server, copy elk-kafka-images.tar and run:

```
cd offline/images
docker load -i elk-kafka-images.tar
docker images | grep -E "(elastic|kafka|akhq|kafbat)"
```

### Step 4: Generate TLS Certificates
On any one server (or secure machine):

```
cd certificates/elasticsearch
./generate-certs.sh
```
This creates certificates for:

HTTP TLS (es01-http.p12, es02-http.p12, es03-http.p12)

Transport TLS (es01-transport.p12, etc.)

Copy generated certs to each Elasticsearch node at:

es01: /opt/elastic/es01/certs/

es02: /opt/elastic/es02/certs/

es03: /opt/elastic/es03/certs/

### Step 5: Configure Your Environment
Copy and edit inventory:

```
cp inventory/hosts.example.yml inventory/hosts.your-env.yml
vim inventory/hosts.your-env.yml
```
Update with your actual server IPs/hostnames.

### Step 6: Bootstrap Cluster (Sequential)
Order matters! Deploy in this exact sequence:

1. Kafka Controllers (3 nodes):

```
# On kafka-controller01, kafka-controller02, kafka-controller03:
docker compose -f kafka/docker-compose.kafka-controllers.yml up -d
docker logs kafka-controller01  # Verify startup
```

2. Kafka Brokers (2 nodes):

```
# On kafka-broker01, kafka-broker02:
docker compose -f kafka/docker-compose.kafka-brokers.yml up -d
docker logs kafka-broker01
```

3. Create Kafka Topics:

```
cd kafka/topics
./create-topics.sh
```

4. Elasticsearch (3 nodes - SEQUENTIAL):

# First node:
```
docker compose -f elasticsearch/docker-compose.es01.yml up -d
docker logs -f es-kiblog1  # Wait for "Elasticsearch started"
sleep 30
```
# Second node:
```
docker compose -f elasticsearch/docker-compose.es02.yml up -d
docker logs -f es-kiblog2
sleep 30
```
# Third node:
```
docker compose -f elasticsearch/docker-compose.es03.yml up -d
docker logs -f es-kiblog3
```

5. Set Kibana System User Password:


# On es01 node:
```
docker exec es-kiblog1 bin/elasticsearch-reset-password -u kibana_system -a
```
# Save the generated password for Kibana config

6. Kibana (1 or 2 nodes):

# Update env/kibana.env with kibana_system password
```
docker compose -f kibana/docker-compose.kibana01.yml up -d
docker logs -f kibana-01
```

7. Logstash (1 or 2 nodes):

# Update env/logstash.env with elastic user password
```
docker compose -f logstash/docker-compose.logstash01.yml up -d
docker logs -f logstash-01
```

8. UIs (Optional, 1 node):

```
docker compose -f ui/docker-compose.akhq-kafka-ui.yml up -d
```

Step 7: Health Check

Run the health verification script:
```
./scripts/check-health.sh
```
Should output:

✓ Elasticsearch cluster health: GREEN
✓ Kafka brokers: 2 registered
✓ Kibana: RUNNING
✓ Logstash: RUNNING

📋 Directory Structure
elk-kafka-offline-cluster/
├── README.md                          # This file
├── LICENSE
├── .gitignore
│
├── docs/                              # Documentation
│   ├── architecture-overview.md
│   ├── offline-installation.md
│   ├── ssl-certificates.md
│   ├── elasticsearch-setup.md
│   ├── kafka-kraft-setup.md
│   ├── logstash-kibana-setup.md
│   ├── operations-and-troubleshooting.md
│   └── host-layout-example.md
│
├── inventory/                         # Server configuration
│   ├── hosts.example.yml              # Template
│   └── hosts.your-env.yml             # Your environment (gitignored)
│
├── offline/                           # Offline installation
│   ├── docker/
│   │   ├── download-docker.sh
│   │   ├── install-docker-offline.sh
│   │   ├── install-docker-offline.md
│   │   └── packages/
│   ├── images/
│   │   ├── download-images.sh
│   │   ├── load-images.sh
│   │   ├── image-list.txt
│   │   └── (elk-kafka-images.tar)
│   └── elastic-bundles/
│       └── certutil-instructions.md
│
├── certificates/                      # TLS certificate generation
│   ├── elasticsearch/
│   │   ├── instances.yml
│   │   ├── generate-certs.sh
│   │   ├── README.md
│   │   ├── http/                      # (generated)
│   │   └── transport/                 # (generated)
│   └── kafka/
│       └── README.md
│
├── env/                               # Environment variables
│   ├── elastic.env.example
│   ├── kibana.env.example
│   ├── logstash.env.example
│   ├── kafka-broker.env.example
│   ├── kafka-controller.env.example
│   └── .gitignore
│
├── elasticsearch/                     # ES deployment
│   ├── docker-compose.es01.yml
│   ├── docker-compose.es02.yml
│   ├── docker-compose.es03.yml
│   ├── config/
│   │   ├── es01/elasticsearch.yml
│   │   ├── es02/elasticsearch.yml
│   │   └── es03/elasticsearch.yml
│   └── README.md
│
├── kibana/                            # Kibana deployment
│   ├── docker-compose.kibana01.yml
│   ├── docker-compose.kibana02.yml
│   ├── config/
│   │   └── kibana.yml.example
│   └── README.md
│
├── logstash/                          # Logstash pipelines
│   ├── docker-compose.logstash01.yml
│   ├── docker-compose.logstash02.yml
│   ├── pipeline/
│   │   ├── kafka-to-elasticsearch.conf
│   │   └── beats-to-kafka.conf
│   ├── config/
│   │   ├── logstash.yml
│   │   └── pipelines.yml
│   └── README.md
│
├── kafka/                             # Kafka deployment
│   ├── docker-compose.kafka-controllers.yml
│   ├── docker-compose.kafka-brokers.yml
│   ├── config/
│   │   ├── controller1.properties
│   │   ├── controller2.properties
│   │   ├── controller3.properties
│   │   ├── broker1.properties
│   │   └── broker2.properties
│   ├── topics/
│   │   ├── topics.yml
│   │   └── create-topics.sh
│   └── README.md
│
├── ui/                                # Kafka UIs
│   ├── docker-compose.akhq-kafka-ui.yml
│   └── README.md
│
└── scripts/                           # Utilities
    ├── bootstrap-all.sh
    ├── check-health.sh
    ├── generate-passwords.md
    └── system-tuning.md

🔧 Operations
Health Status
Service	Command	Expected
Elasticsearch	curl -u elastic:PASSWORD https://es01:9200/_cluster/health	"status":"green"
Kafka Quorum	docker exec kafka-controller01 kafka-metadata-quorum.sh --bootstrap-controller localhost:9093 describe --status	"status":"Leader"
Kibana	curl https://kibana01:5601/api/status	HTTP 200
Logstash	curl localhost:9600/_node/stats	"status":"green"
Useful URLs (Web UIs)
Kibana: https://kibana01:5601 (username: elastic or kibana_system)

AKHQ: http://kibana01:8080 (Kafka management)

Kafka-UI: http://kibana01:8081 (Alternative Kafka UI)

Common Operations
Reset Elastic User Password:

```
docker exec es-kiblog1 bin/elasticsearch-reset-password -u elastic -a
Check Kafka Brokers:
```
```
docker exec kafka-broker01 kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```
View Elasticsearch Nodes:
```
curl -u elastic:PASSWORD https://es01:9200/_cat/nodes?v
```
⚠️ Security Notes
Change Default Passwords: All env/*.example files contain default credentials. Update before production.

TLS Certificates: Self-signed certificates are generated for convenience. For production, use CA-signed certificates.

Security Enabled: xpack.security.enabled: true on all components. Credentials required.

Network:

Elasticsearch: ports 9200 (HTTP), 9300 (Transport)

Kibana: port 5601

Kafka: ports 9092 (PLAINTEXT), 9093 (CONTROLLER)

Configure firewall accordingly

Air-Gapped: Network isolation is your security layer. Validate images before loading.

📚 Documentation
Architecture Overview - High-level design and decisions

Offline Installation - Step-by-step offline install guide

SSL Certificates - Generating and managing TLS certificates

Elasticsearch Setup - ES cluster configuration and tuning

Kafka KRaft Setup - KRaft quorum and broker configuration

Logstash + Kibana Setup - Pipelines and UI configuration

Operations & Troubleshooting - Common issues and fixes

Host Layout Example - Detailed server role assignment

🤝 Contributing
Fork this repository

Test changes in your environment (update inventory/hosts.your-env.yml)

Verify all components start and health checks pass

Submit PR with detailed changes

❓ Troubleshooting Quick Links
Docker fails to load images: See offline/images/README.md

Elasticsearch won't join cluster: See docs/elasticsearch-setup.md

Kafka metadata stuck: See docs/kafka-kraft-setup.md

Logstash can't connect to ES: See docs/logstash-kibana-setup.md

📄 License
MIT License - See LICENSE file for details.

