# System Tuning (Linux)

Apply on all Elasticsearch hosts.

## vm.max_map_count

```bash
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-elasticsearch.conf
sudo sysctl --system

Verify

sysctl vm.max_map_count
