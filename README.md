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
- SSH access to the target server
- Vault password file for encrypted variables, if you use `/inventory/group_vars/webservers/vault.yml`

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

If your `/inventory/group_vars/webservers/vault.yml` contains encrypted values, create a local vault password file in the project root:

```
echo "your-vault-password" > vault-password-file
chmod 600 vault-password-file
```

The file is ignored by git and is not committed to the repository.

## Observability

### Ports and access

- **80 / 443** — Nginx, public (HTTP to HTTPS redirect, HTTPS reverse proxy).
- **8080** — application, reachable from `127.0.0.1` only.
- **9090** — Spring Actuator management port, reachable from `127.0.0.1` only. `health` and `prometheus` are proxied through Nginx.
- **9100** — Node Exporter. Access must be limited to the monitoring server (UFW / Security Group).

### Endpoints through Nginx

Base URL: `https://aleks-devops.ru`

- `/actuator/health` — open, returns status only.
- `/actuator/prometheus` — protected with Basic Auth.
- any other `/actuator/...` — denied.

### Basic authentication

The metrics endpoint is protected by Nginx Basic Auth. The user name and the path to the password file are role variables, the password is stored in Ansible Vault. Node Exporter has no authentication at this stage, access to port 9100 is restricted at the network level.

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
| CPU load | `node_load1` | 1-minute load average |
| Memory | `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100` | Memory usage, % |
| Disk | `node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100` | Free space on `/`, % |
| Disk | `node_filesystem_files_free / node_filesystem_files * 100` | Free inodes, % |
| Disk | `rate(node_disk_reads_completed_total[5m]) + rate(node_disk_writes_completed_total[5m])` | Disk operations per second |
| Network | `rate(node_network_receive_bytes_total{device!~"lo\|veth.*\|docker.*\|br-.*"}[5m]) * 8` | Incoming traffic, bit/s |
| Network | `rate(node_network_transmit_bytes_total{device!~"lo\|veth.*\|docker.*\|br-.*"}[5m]) * 8` | Outgoing traffic, bit/s |
| Network | `rate(node_network_receive_errs_total[5m])` | Receive errors per second |
| Network | `rate(node_network_transmit_errs_total[5m])` | Transmit errors per second |
| Processes | `node_procs_running` | Running processes |
| Processes | `node_procs_blocked` | Processes blocked on I/O |
| Services | `node_systemd_unit_state{name="nginx.service",state="active"}` | 1 if Nginx is running |
| Services | `node_systemd_unit_state{name="docker.service",state="active"}` | 1 if Docker is running |

Application metrics (Spring Boot Actuator / Micrometer):

| Metric | What it shows |
|--------|---------------|
| `process_uptime_seconds` | Application uptime, helps to notice restarts |
| `http_server_requests_seconds_count` | HTTP requests by `uri`, `method`, `status` and `outcome` |
| `http_server_requests_seconds_bucket` | Request duration histogram, used for latency percentiles |
| `process_cpu_usage` | CPU usage of the application process |
| `jvm_memory_used_bytes` | JVM memory usage |
| `hikaricp_connections_active` | Active database connections |

### Verification commands

Run on the server (ports 9090 and 9100 are not reachable from outside):

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
