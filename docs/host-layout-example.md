# Host Layout Example

This is a topology template only. No environment-specific addresses are included.

## Elasticsearch

| Node | Address |
|---|---|
| es01 | `<ES01_IP>` |
| es02 | `<ES02_IP>` |
| es03 | `<ES03_IP>` |

## Kibana

| Node | Address |
|---|---|
| kibana01 | `<KIBANA01_IP>` |
| kibana02 | `<KIBANA02_IP>` |

## Logstash

| Node | Address |
|---|---|
| logstash01 | `<LOGSTASH01_IP>` |
| logstash02 | `<LOGSTASH02_IP>` |

## Kafka (KRaft)

### Controllers

| Node | Address |
|---|---|
| controller01 | `<CONTROLLER01_IP>` |
| controller02 | `<CONTROLLER02_IP>` |
| controller03 | `<CONTROLLER03_IP>` |

### Brokers

| Node | Address |
|---|---|
| broker01 | `<BROKER01_IP>` |
| broker02 | `<BROKER02_IP>` |
| broker03 | `<BROKER03_IP>` |

## Optional UI Host

- Address: `<UI_HOST_IP>`
- AKHQ: `8080`
- Kafka UI: `8081`

## Notes

- Replace placeholders locally with the addresses used by the deployment.
- This repository uses host networking in the Compose examples.
- Keep environment-specific inventory files outside Git.
