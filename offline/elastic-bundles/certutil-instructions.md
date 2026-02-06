# Elastic Certificate Utility (certutil) Overview

Elasticsearch provides the `elasticsearch-certutil` tool to generate:

- A Certificate Authority (CA)
- Node certificates for:
  - HTTP (client-facing)
  - Transport (cluster-internal)

In this repository, we use `certificates/elasticsearch/instances.yml` as input to
`elasticsearch-certutil` to generate all required certificates for the 3-node cluster
(es01, es02, es03).

The detailed commands are in:

- `certificates/elasticsearch/generate-certs.sh`
- `docs/ssl-certificates.md`

You typically run cert generation once on a secure machine, then distribute the
generated files to each Elasticsearch / Kibana / Logstash node.
