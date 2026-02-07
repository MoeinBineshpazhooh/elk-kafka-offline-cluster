# Kafka UIs (AKHQ + Kafka UI)

This folder runs two optional web UIs for Kafka:

- AKHQ: http://<ui-host>:8080
- Kafka UI: http://<ui-host>:8081

Both services use host networking (`network_mode: host`).

## Prerequisites

- Kafka brokers are running and reachable:
  - 10.10.4.131:9092
  - 10.10.4.132:9092

## Start

On the UI host:

```bash
cd ui
docker compose -f docker-compose.akhq-kafka-ui.yml up -d
docker logs -f akhq
docker logs -f kafka-ui

URLs
AKHQ: http://<ui-host>:8081
Kafka UI: http://<ui-host>:8082
Notes
If you change broker IPs/ports, update them in docker-compose.akhq-kafka-ui.yml.
For secured Kafka (SASL/TLS), additional configuration is required (not enabled in this repo by default).
