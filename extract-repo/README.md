# extract-repo

This folder produces offline-friendly tar.gz bundles from this repository using `git archive`.

Why:
- In an offline environment you may not have GitHub access.
- You may want to copy only the required files to each server (per role).

## Outputs (role-based)

Running the script generates these artifacts:

- `es-controller.tar.gz`  (Elasticsearch + Kafka controllers) -> for es01/es02/es03 (controllers colocated)
- `kafka-broker.tar.gz`   (Kafka brokers) -> for broker01/broker02
- `kibana.tar.gz`         -> for kibana01/kibana02
- `logstash.tar.gz`       -> for logstash01/logstash02
- `ui.tar.gz`             (AKHQ + Kafka-UI) -> for ui host

Each archive is created with a prefix `elk-bundle/` so extraction results in:
`/opt/elk/elk-bundle/...`

## Build bundles (online/build machine)

From repo root:

```
bash extract-repo/build-bundles.sh dist/bundles HEAD
```
You can replace HEAD with a tag or commit hash.

Transfer to offline servers
Copy the needed tar.gz file(s) to each target host using your approved method.

Extract (offline target)
Example target directory: /opt/elk
```
sudo mkdir -p /opt/elk
sudo tar --no-same-owner -xzf es-controller.tar.gz -C /opt/elk
```
After extraction, you will have:
```
/opt/elk/elk-bundle/
```
Then follow the component READMEs and scripts/bootstrap-all.sh.

