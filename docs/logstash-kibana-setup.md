# Logstash + Kibana Setup

This document explains how to connect Kibana and Logstash to a secured Elasticsearch cluster (HTTPS + security enabled).

## Kibana -> Elasticsearch

Kibana uses the built-in user `kibana_system` to connect to Elasticsearch.
Make sure:
- Elasticsearch is reachable via HTTPS
- Kibana has the correct CA certificate mounted
- `ELASTICSEARCH_USERNAME=kibana_system` and its password are set

See: `kibana/README.md`

## Logstash (Kafka -> Elasticsearch)

### What this pipeline does
- Input: Kafka topics
- Output: Elasticsearch over HTTPS using basic auth
- Trust: Elasticsearch CA certificate

### Required files
- `logstash/pipeline/kafka-to-elasticsearch.conf`
- `logstash/config/logstash.yml`
- `logstash/config/pipelines.yml`
- `env/logstash.env`

### Configure env/logstash.env

Copy the example:

```bash
cp env/logstash.env.example env/logstash.env

Set at least:
KAFKA_BOOTSTRAP_SERVERS
KAFKA_TOPICS (Ruby array string)
ELASTICSEARCH_HOSTS
ELASTICSEARCH_USERNAME
ELASTICSEARCH_PASSWORD
CA certificate
Copy ca.crt to each Logstash node:
/opt/elastic/logstash01/certs/ca/ca.crt
/opt/elastic/logstash02/certs/ca/ca.crt
Start Logstash
On logstash01 host:

cd logstash
docker compose -f docker-compose.logstash01.yml up -d

On logstash02 host:

cd logstash
docker compose -f docker-compose.logstash02.yml up -d

Verify Logstash
Check Logstash API:

curl http://127.0.0.1:9600/_node/pipelines?pretty

Troubleshooting tips:
If you get SSL errors, verify CA path and that Elasticsearch is using HTTPS.
If you get auth errors, verify Elasticsearch username/password.
If Kafka consumption is not balanced, verify both Logstash nodes use the same KAFKA_GROUP_ID.
