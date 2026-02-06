# Password Management (Elasticsearch Built-in Users)

This guide explains how to set/reset passwords for built-in Elastic Stack users in a self-managed cluster.

## Built-in users (common)

- `elastic` (superuser)
- `kibana_system` (Kibana uses this to talk to Elasticsearch)
- `logstash_system` (Logstash uses this for monitoring when enabled)

## Where to run commands

Run password reset commands on any Elasticsearch node that is running, for example on `es01`:

```bash
docker exec -it es01 bash

Reset elastic (interactive)

bin/elasticsearch-reset-password -u elastic -i

Reset kibana_system (auto)

bin/elasticsearch-reset-password -u kibana_system -a -y

Copy the generated password and put it into:
env/kibana.env as ELASTICSEARCH_PASSWORD
Reset logstash_system (auto)

bin/elasticsearch-reset-password -u logstash_system -a -y

Note:
This user is used for Logstash monitoring features. For Logstash pipelines that write data to Elasticsearch,
you should create a dedicated user with minimal privileges (recommended for production).
Verify credentials

curl -k -u elastic:<PASSWORD> https://10.10.4.101:9200/_cluster/health?pretty

