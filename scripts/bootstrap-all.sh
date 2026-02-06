#!/usr/bin/env bash
set -euo pipefail

# Bootstrap runbook (manual orchestration helper)
# This script prints the recommended deployment order and example commands.

cat <<'TXT'
ELK + Kafka Offline Cluster Bootstrap Order
==========================================

0) System tuning (all nodes)
----------------------------
- Apply: scripts/system-tuning.md

1) Offline Docker install (all nodes)
-------------------------------------
- offline/docker/install-docker-offline.sh

2) Load images (nodes that run containers)
------------------------------------------
- offline/images/load-images.sh

3) TLS certificates (one secure machine)
----------------------------------------
- certificates/elasticsearch/generate-certs.sh
- Distribute:
  - ES nodes: /opt/elastic/es0X/certs (ca.crt + es0X-http.p12 + es0X-transport.p12)
  - Kibana nodes: /opt/elastic/kibana0X/certs/ca/ca.crt
  - Logstash nodes: /opt/elastic/logstash0X/certs/ca/ca.crt

4) Kafka KRaft
--------------
A) Generate cluster UUID (once):
   docker run --rm apache/kafka:latest bash -lc "/opt/kafka/bin/kafka-storage.sh random-uuid"

B) Start controllers (on controller nodes):
   cd kafka
   set -a; source ../env/kafka-controller.env; set +a
   docker compose -f docker-compose.controller01.yml up -d
   docker compose -f docker-compose.controller02.yml up -d
   docker compose -f docker-compose.controller03.yml up -d

C) Start brokers (on broker nodes):
   set -a; source ../env/kafka-broker.env; set +a
   docker compose -f docker-compose.broker01.yml up -d
   docker compose -f docker-compose.broker02.yml up -d

D) Create topics:
   cd kafka/topics
   BOOTSTRAP_SERVERS="10.10.4.131:9092,10.10.4.132:9092" ./create-topics.sh

5) Elasticsearch (sequential)
-----------------------------
On es01:
  cd elasticsearch
  set -a; source ../env/elastic.env; set +a
  docker compose -f docker-compose.es01.yml up -d

On es02:
  docker compose -f docker-compose.es02.yml up -d

On es03:
  docker compose -f docker-compose.es03.yml up -d

6) Set passwords (once ES is up)
--------------------------------
- scripts/generate-passwords.md

7) Kibana (choose HTTP or HTTPS variant)
----------------------------------------
On kibana01:
  cd kibana
  docker compose -f docker-compose.kibana01.yml up -d
  # OR: docker-compose.kibana01.https.yml

On kibana02:
  docker compose -f docker-compose.kibana02.yml up -d
  # OR: docker-compose.kibana02.https.yml

8) Logstash
-----------
On logstash01:
  cd logstash
  docker compose -f docker-compose.logstash01.yml up -d

On logstash02:
  docker compose -f docker-compose.logstash02.yml up -d

9) Kafka UIs (optional)
-----------------------
On ui host:
  cd ui
  docker compose -f docker-compose.akhq-kafka-ui.yml up -d

10) Health check
----------------
- scripts/check-health.sh

TXT
