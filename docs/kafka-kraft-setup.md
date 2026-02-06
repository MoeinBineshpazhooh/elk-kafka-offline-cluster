# Kafka KRaft Setup (Host Networking)

This guide deploys Kafka in KRaft mode using:
- 3 controllers
- 2 brokers
- host networking (`network_mode: host`)

## KRaft Requirements

- Each server has a unique `node.id` across the entire cluster.
- All nodes use the same `controller.quorum.voters` string.
- Generate ONE Cluster UUID and format storage on EACH controller and broker node with that UUID before first start.

## Node IDs (as shipped in this repo)

Controllers:
- controller01: node.id=1
- controller02: node.id=2
- controller03: node.id=3

Brokers:
- broker01: node.id=4
- broker02: node.id=5

## Step 1 — Prepare folders

On controller hosts:
```bash
sudo mkdir -p /opt/kafka/controller/data

On broker hosts:

sudo mkdir -p /opt/kafka/broker/data

Step 2 — Generate Cluster UUID (once)

docker run --rm apache/kafka:latest bash -lc "/opt/kafka/bin/kafka-storage.sh random-uuid"

Set it in:
env/kafka-controller.env
env/kafka-broker.env
Step 3 — Start controllers
controller01:

cd kafka
set -a; source ../env/kafka-controller.env; set +a
docker compose -f docker-compose.controller01.yml up -d
docker logs -f kafka-controller01

controller02:

cd kafka
set -a; source ../env/kafka-controller.env; set +a
docker compose -f docker-compose.controller02.yml up -d
docker logs -f kafka-controller02

controller03:

cd kafka
set -a; source ../env/kafka-controller.env; set +a
docker compose -f docker-compose.controller03.yml up -d
docker logs -f kafka-controller03

Step 4 — Start brokers
broker01:

cd kafka
set -a; source ../env/kafka-broker.env; set +a
docker compose -f docker-compose.broker01.yml up -d
docker logs -f kafka-broker01

broker02:

cd kafka
set -a; source ../env/kafka-broker.env; set +a
docker compose -f docker-compose.broker02.yml up -d
docker logs -f kafka-broker02

Step 5 — Create topics

cd kafka/topics
BOOTSTRAP_SERVERS="10.10.4.131:9092,10.10.4.132:9092" ./create-topics.sh

Verification
Controller quorum:

docker exec kafka-controller01 bash -lc "/opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-controller 10.10.4.121:9093 describe --status"

Broker connectivity:

docker exec kafka-broker01 bash -lc "/opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server 10.10.4.131:9092"

