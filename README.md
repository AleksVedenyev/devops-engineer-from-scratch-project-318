[![hexlet-check](https://github.com/AleksVedenyev/devops-engineer-from-scratch-project-318/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/AleksVedenyev/devops-engineer-from-scratch-project-318/actions/workflows/hexlet-check.yml)

# Доска объявлений (Observability)

Infrastructure-as-Code repository for the bulletin board application.

## Project link

The application repository is available here:

- https://github.com/AleksVedenyev/project-devops-deploy

## Description

This repository contains the infrastructure code used to provision, deploy and monitor the application:

- Ansible playbooks
- inventory
- group variables
- role and collection requirements
- deployment commands in Makefile

The application itself is containerized in the application fork, while this repository is responsible only for infrastructure, deployment and monitoring agents.

## Requirements

- Ansible
- SSH access to the target servers
- Vault password file for encrypted variables, if you use `inventory/group_vars/webservers/vault.yml`

## Ansible dependencies

Third-party roles and collections are listed in `requirements.yml`.

Install them with:

```
make requirements
```

## Server setup

Prepare the target server for deployment with:

```
make setup
```

This runs `playbook.yml` and installs Docker, Nginx, Certbot and Node Exporter, configures the reverse proxy (HTTPS, JSON access logs, protected metrics endpoint) and applies basic firewall rules.

## Deployment

The application is deployed with Ansible and can be started with:

```
make deploy
```

By default this deploys the `latest` image tag.

To deploy or roll back to a specific version, pass the immutable SHA-based tag published by CI:

```
make deploy IMAGE_TAG=<git-commit-sha>
```

## Vault password file

If your `inventory/group_vars/webservers/vault.yml` contains encrypted values, create a local vault password file in the project root:

```
echo "your-vault-password" > vault-password-file
chmod 600 vault-password-file
```

The file is ignored by git and is not committed to the repository.

## Observability

### Ports and access

Application server (group `webservers`):

- **80 / 443** — Nginx, public (HTTP to HTTPS redirect, HTTPS reverse proxy).
- **8080** — application, reachable from `127.0.0.1` only.
- **9090** — Spring Actuator management port, reachable from `127.0.0.1` only. `health` and `prometheus` are proxied through Nginx.
- **9100** — Node Exporter, allowed only from the internal IP of the monitoring server (UFW and Security Group).

Monitoring server (group `monitoring`):

- **22** — SSH.
- **9090** — Prometheus UI.

All other ports are closed by UFW and the Security Group.

### Endpoints through Nginx

Base URL: `https://aleks-devops.ru`

- `/actuator/health` — open, returns status only.
- `/actuator/prometheus` — protected with Basic Auth.
- any other `/actuator/...` — denied.

### Basic authentication

The metrics endpoint is protected by Nginx Basic Auth. The user name and the path to the password file are role variables, the password is stored in Ansible Vault. Prometheus uses the same credentials when it scrapes the endpoint. Node Exporter has no authentication, access to port 9100 is restricted at the network level.

### Nginx logs

The access log (`/var/log/nginx/access.log`) is written in JSON, one object per line: time, client IP, method, path, status, response size, request time, upstream time, referer and user agent. Requests to the health and metrics endpoints are not logged.

The error log stays in plain text, because Nginx does not support a custom format for it.

### Node Exporter

Node Exporter is installed by the `prometheus.prometheus.node_exporter` role as a systemd service and is restarted when its configuration changes. In addition to the default collectors, `systemd` and `processes` are enabled.

### Required metrics

Host metrics (Node Exporter):

| Area | Metric | What it shows |
|------|--------|---------------|
| CPU | `100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | CPU utilization, % |
| CPU load | `node_load1 node_load5 node_load15` | 1, 5, 15-minute load average |
| Memory | `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100` | Memory usage, % |
| Disk | `node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100` | Free space on `/`, % |
| Disk | `node_filesystem_files_free / node_filesystem_files * 100` | Free inodes, % |
| Disk | `rate(node_disk_reads_completed_total[5m]) + rate(node_disk_writes_completed_total[5m])` | Disk operations per second |
| Network | `rate(node_network_receive_bytes_total{device!~"lo\|veth.*\|docker.*\|br-.*"}[5m]) * 8` | Incoming traffic, bit/s |
| Network | `-1 * rate(node_network_transmit_bytes_total{device!~"lo\|veth.*\|docker.*\|br-.*"}[5m]) * 8` | Outgoing traffic, bit/s |
| Network | `rate(node_network_receive_errs_total[5m])` | Receive errors per second |
| Network | `rate(node_network_transmit_errs_total[5m])` | Transmit errors per second |
| Processes | `node_procs_running` | Running processes |
| Services | `node_systemd_unit_state{name="nginx.service",state="active"}` | 1 if Nginx is running |
| Services | `node_systemd_unit_state{name="docker.service",state="active"}` | 1 if Docker is running |

Application metrics (Spring Boot Actuator / Micrometer):

| Metric | What it shows |
|--------|---------------|
| `process_uptime_seconds` | Application uptime, helps to notice restarts |
| `http_server_requests_seconds_count` | HTTP requests by `uri`, `method`, `status` and `outcome` |
| `http_server_requests_seconds_bucket` | Request duration histogram, used for latency percentiles |
| `process_cpu_usage` | CPU usage of the application process |

### Monitoring server (Prometheus)

Prometheus and Grafana run on a separate VM from the `monitoring` group of the inventory. They are deployed together with Ansible and can be redeployed at any time with one command:

```
make monitoring_setup
```

The role renders Prometheus, Grafana, datasource and dashboard provisioning files, validates Prometheus configuration with promtool, and starts both containers with Docker Compose.

The configuration, alert rules, datasource provisioning and dashboard JSON files are stored in this repository. Sensitive data (Grafana admin password and the Basic Auth password for /actuator/prometheus) is stored in Ansible Vault.

Scrape targets:

| Job | Target | Notes |
|-----|--------|-------|
| `node` | internal IP of the application server, port `9100` | Node Exporter |
| `app` | `https://aleks-devops.ru/actuator/prometheus` | Basic Auth |

### Grafana

Grafana UI: `http://153.51.117.166:3000`

- Login: `metrics-collector`
- Password: stored in Ansible Vault

The UI is provisioned automatically from YAML/JSON files in the repository. After changing dashboard JSON or provisioning files, run:

```
make monitoring_setup
```

### Prometheus UI

Prometheus UI: `http://<monitoring-vm-ip>:9090`. The UI is available without authentication in this learning setup.

- Graph: `http://<monitoring-vm-ip>:9090/graph`
- Targets: `http://<monitoring-vm-ip>:9090/targets` (Status → Target health)

Check that all targets are up: open the Graph page and run the query:

```
up
```

Both series, `job="node"` and `job="app"`, must have the value `1`. 

### Alerting

Grafana alerting is configured on the monitoring server.

#### Critical events

The following alert rules are configured:

- application down / no metrics for a configured period of time
- node exporter / host down / no metrics for a configured period of time
- high CPU usage
- high memory usage
- low disk space
- high 5xx error rate

#### Contact point

Alerts are delivered by email through a Grafana contact point.

- SMTP settings are passed to the Grafana container through environment variables
- the SMTP password is stored in Ansible Vault
- the recipient address is configured in Grafana UI

#### Alert rules

Alert rules are stored in the repository and are deployed together with the monitoring stack by Ansible.

To inspect the rules in Grafana:

- open Grafana UI
- go to **Alerting → Alert rules**

#### How to trigger a test alert

You can trigger alerts manually by creating the corresponding condition on the application or monitoring host, for example:

- stop the application container to trigger `up == 0`
- increase CPU load on the application server to trigger the CPU alert
- fill the disk or lower the free disk threshold to trigger the disk alert

#### Verification

A screenshot of a firing alert is stored in the `assets/` directory.

#### Update monitoring stack

After changing alert rules or dashboards, redeploy the monitoring stack with:

```
make monitoring_setup
```

### Verification commands

Run on the application server (ports 9090 and 9100 are not reachable from outside):

```
curl http://127.0.0.1:9090/actuator/prometheus
curl http://127.0.0.1:9090/actuator/health
curl http://127.0.0.1:9100/metrics
```

Through Nginx:

```
curl -i https://aleks-devops.ru/actuator/health
curl -i https://aleks-devops.ru/actuator/prometheus
curl -u <user>:<password> https://aleks-devops.ru/actuator/prometheus
```

The second command returns `401`, the other two return `200`.
