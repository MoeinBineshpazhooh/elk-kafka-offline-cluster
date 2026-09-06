# Kibana Saved Objects

This directory documents the portable Kibana objects used by the portfolio dashboard.

## Import

Kibana supports NDJSON Saved Object import through the Saved Objects UI and HTTP API. Elastic recommends preserving migration metadata when storing exported objects outside Kibana; objects exported directly from a running Kibana instance should be treated as opaque. See the Elastic documentation for the exact version-specific export format.

### UI

1. Open **Stack Management → Saved Objects**.
2. Select **Import**.
3. Import `../saved-objects.ndjson`.
4. Allow overwriting existing objects with the same IDs when updating the portfolio deployment.
5. Open the dashboard **Enterprise Observability — Demo Logs**.

### API

```bash
curl --fail --silent --show-error \
  -X POST "${KIBANA_URL}/api/saved_objects/_import?overwrite=true" \
  -H 'kbn-xsrf: true' \
  -H 'Content-Type: application/ndjson' \
  --data-binary @kibana/saved-objects.ndjson
```

Use a locally defined `KIBANA_URL`; do not commit environment-specific addresses or credentials.

## Data View

The bundle uses the portfolio-safe data view:

```text
demo-logs-*
```

with:

```text
@timestamp
```

as the time field.

## Dashboard contract

The dashboard is intentionally tied to the fields that the example ingestion configuration can produce. Do not add panels for infrastructure-specific fields unless those fields are explicitly present in the target mapping.

Recommended operational panels for a local deployment are:

- event volume over time
- service/source distribution
- log-level distribution when `log.level` exists
- recent events using `@timestamp` and `message`
- error-focused views when the incoming events contain a compatible log-level field

If the local deployment uses a different mapping, export the Data View and dashboard from that Kibana instance after validating the field names.

## Versioning

The repository targets Kibana 9.2.x. Saved Object exports are version-sensitive. When upgrading Kibana, re-export the dashboard from the target version and replace the repository bundle rather than manually editing generated migration metadata.
