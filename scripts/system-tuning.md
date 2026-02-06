# System Tuning (Linux) for ELK + Kafka

This document contains recommended Linux kernel and user-limit settings for running:
- Elasticsearch
- Kafka
- Logstash

Apply these settings on the target servers before starting containers (especially Elasticsearch).

## 1) vm.max_map_count (Required for Elasticsearch)

Elasticsearch requires `vm.max_map_count` to be at least **262144**. [Ref: Elastic guidance, common production requirement]

Check current value:

```bash
sysctl vm.max_map_count

Temporary (until reboot):

sudo sysctl -w vm.max_map_count=262144

Persistent:

echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-elasticsearch.conf
sudo sysctl --system

Verify:

sysctl vm.max_map_count


2) File descriptor limits (nofile)
Elasticsearch and Kafka use many open files. Recommended:
nofile >= 65536
Check:

ulimit -n

If you run containers with docker-compose, ulimits can be set in compose files (already included).
For host-level tuning, create:

/etc/security/limits.d/99-elk-kafka.conf


sudo tee /etc/security/limits.d/99-elk-kafka.conf >/dev/null <<'LIM'
* soft nofile 65536
* hard nofile 65536
LIM

Log out and log in again (or reboot) to apply.
3) Memory locking (memlock) (Recommended for Elasticsearch)
To reduce swapping and improve stability, Elasticsearch often benefits from memory lock.
Compose files set:
memlock soft/hard: -1
Also make sure swap is not actively harming performance.
Check swap:

swapon --show
free -h

Optional: reduce swapping tendency:

echo "vm.swappiness=1" | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl --system


4) Disable Transparent Huge Pages (THP) (Recommended)
THP can cause latency spikes for JVM workloads.
Check THP status:

cat /sys/kernel/mm/transparent_hugepage/enabled || true
cat /sys/kernel/mm/transparent_hugepage/defrag || true

Temporary disable:

echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag

Persistent disable (systemd unit):

sudo tee /etc/systemd/system/disable-thp.service >/dev/null <<'UNIT'
[Unit]
Description=Disable Transparent Huge Pages (THP)
After=sysinit.target local-fs.target
Before=docker.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'
ExecStart=/bin/sh -c 'echo never > /sys/kernel/mm/transparent_hugepage/defrag'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable disable-thp
sudo systemctl start disable-thp

5) Recommended minimum resources (guideline)
These are rough baseline recommendations:
Elasticsearch nodes: 4 CPU / 16 GB RAM (heap ~ 2-8 GB depending on workload)
Kafka brokers: 4 CPU / 8-16 GB RAM
Kibana: 2 CPU / 4 GB RAM
Logstash: 2 CPU / 4-8 GB RAM
Adjust based on your ingestion rate and retention.
