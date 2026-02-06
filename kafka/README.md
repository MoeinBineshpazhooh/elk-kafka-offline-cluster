# Kafka (KRaft) - 3 Controllers + 2 Brokers (Host Networking)

This folder deploys a Kafka cluster in **KRaft mode** (no ZooKeeper):

- Controllers: kafka-controller01..03 (node.id 1..3)
- Brokers: kafka-broker01..02 (node.id 4..5)

KRaft requires:
- `node.id` unique across the cluster
- identical `controller.quorum.voters` on all nodes
- a single Cluster UUID used to format storage on **each node** before first start

## Prerequisites

- Docker installed (offline ok)
- Images loaded (`apache/kafka:latest`)
- Host directories exist on each Kafka node:
  - Controllers: `/opt/kafka/controller/data`
  - Brokers: `/opt/kafka/broker/data`

## Step 1 — Generate Cluster UUID (once)

Run on any machine with the Kafka image:

```bash
docker run --rm apache/kafka:latest bash -lc "/opt/kafka/bin/kafka-storage.sh random-uuid"

Set the output UUID in:
env/kafka-controller.env
env/kafka-broker.env
Step 2 — Start Controllers (3 nodes)
On controller01 host:

sudo mkdir -p /opt/kafka/controller/data
cd kafka
set -a; source ../env/kafka-controller.env; set +a
docker compose -f docker-compose.controller01.yml up -d
docker logs -f kafka-controller01

On controller02 host:

sudo mkdir -p /opt/kafka/controller/data
cd kafka
set -a; source ../env/kafka-controller.env; set +a
docker compose -f docker-compose.controller02.yml up -d
docker logs -f kafka-controller02

On controller03 host:

sudo mkdir -p /opt/kafka/controller/data
cd kafka
set -a; source ../env/kafka-controller.env; set +a
docker compose -f docker-compose.controller03.yml up -d
docker logs -f kafka-controller03

Step 3 — Start Brokers (2 nodes)
On broker01 host:

sudo mkdir -p /opt/kafka/broker/data
cd kafka
set -a; source ../env/kafka-broker.env; set +a
docker compose -f docker-compose.broker01.yml up -d
docker logs -f kafka-broker01

On broker02 host:

sudo mkdir -p /opt/kafka/broker/data
cd kafka
set -a; source ../env/kafka-broker.env; set +a
docker compose -f docker-compose.broker02.yml up -d
docker logs -f kafka-broker02

Step 4 — Create Topics
Run on a host where kafka-broker01 container exists:

cd kafka/topics
BOOTSTRAP_SERVERS="10.10.4.131:9092,10.10.4.132:9092" ./create-topics.sh

Verification
Metadata quorum status (run on a controller host):

docker exec kafka-controller01 bash -lc "/opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-controller 10.10.4.121:9093 describe --status"

Broker connectivity (run on a broker host):

docker exec kafka-broker01 bash -lc "/opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server 10.10.4.131:9092"

