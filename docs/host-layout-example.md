# Host Layout Example (IPs / Roles)

This is an example layout for a small offline cluster.
Adjust to your environment.

## Elasticsearch
- 10.10.4.101: es01
- 10.10.4.102: es02
- 10.10.4.103: es03

## Kibana
- 10.10.4.111: kibana01
- 10.10.4.112: kibana02

## Logstash
- 10.10.4.121: logstash01
- 10.10.4.122: logstash02

## Kafka (KRaft)
Controllers:
- 10.10.4.141: controller01
- 10.10.4.142: controller02
- 10.10.4.143: controller03

Brokers:
- 10.10.4.131: broker01 (9092)
- 10.10.4.132: broker02 (9092)

## Optional UI host
- 10.10.4.150: ui (AKHQ:8080, Kafka UI:8081)

## Notes
- This repo uses host networking for simplicity in offline environments.
- Ensure firewall rules allow required ports within your private network.
