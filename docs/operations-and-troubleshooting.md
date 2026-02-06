# Operations & Troubleshooting

This document collects practical commands and common errors for this repo.

## Git / CI

### Non-fast-forward on push
If you are behind remote:

```bash
git fetch origin
git rebase origin/main
git push

Elasticsearch
Symptom: bootstrap checks failed (vm.max_map_count)
Fix:
sudo sysctl -w vm.max_map_count=262144

Symptom: TLS/CA trust errors from clients
Use the correct CA:

curl --cacert /path/to/ca.crt https://<es-ip>:9200

Symptom: auth failures
Reset passwords:

docker exec -it es01 bash
bin/elasticsearch-reset-password -u elastic -i

Kibana
Symptom: "Kibana server is not ready yet"
Common causes:
Elasticsearch not reachable (network/DNS/port)
Wrong credentials for kibana_system
CA is not mounted/configured correctly (when Elasticsearch uses HTTPS)
Logstash
Symptom: Cannot connect to Elasticsearch (SSL)
Ensure CA file is mounted in the container
Ensure ssl_certificate_authorities points to the CA path inside the container
Symptom: No data consumed from Kafka
Verify Kafka brokers reachable
Verify topic exists
Verify KAFKA_TOPICS env is correct (array format as used in pipeline)
Logstash API:

curl http://127.0.0.1:9600/_node/pipelines?pretty

Kafka
Symptom: Brokers up but clients cannot produce/consume
Verify listeners/advertsied listeners
Verify firewall rules
Verify you are using the correct broker addresses/ports
Optional UIs:
AKHQ: http://<ui-host>:8080
Kafka UI: http://<ui-host>:8081
