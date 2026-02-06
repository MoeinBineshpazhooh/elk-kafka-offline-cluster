# Logstash (Kafka -> Elasticsearch) with TLS

This folder runs Logstash on two nodes (logstash01/logstash02) using host networking.
Each Logstash instance consumes from Kafka topics and writes to Elasticsearch over HTTPS (trusted by CA).

## Prerequisites

1) Kafka brokers must be running.
2) Elasticsearch must be running with HTTPS enabled.
3) Copy `env/logstash.env.example` to `env/logstash.env` and set real values.

## TLS / CA

Copy Elasticsearch CA certificate to each Logstash node:

- From: `certificates/elasticsearch/generated/ca/ca.crt`
- To:
  - logstash01 host: `/opt/elastic/logstash01/certs/ca/ca.crt`
  - logstash02 host: `/opt/elastic/logstash02/certs/ca/ca.crt`

## Topics format

`KAFKA_TOPICS` must be a Ruby array string, e.g.:

- `["app-logs","system-logs"]`

## Start

On logstash01 host:

```bash
cd logstash
docker compose -f docker-compose.logstash01.yml up -d
docker logs -f logstash01

On logstash02 host:

cd logstash
docker compose -f docker-compose.logstash02.yml up -d
docker logs -f logstash02

Verify
Logstash monitoring API (default 9600):

curl http://127.0.0.1:9600/_node/pipelines?pretty

If both instances share the same Kafka group_id, Kafka will distribute partitions among them.
