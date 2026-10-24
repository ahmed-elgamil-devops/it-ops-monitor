# IT Ops Monitor

A small, practical toolkit for an IT team: a **status page** that watches the services a company depends on
(website, Microsoft 365, mail, DNS, file server, printers), **Prometheus + Grafana** monitoring with alerts,
and the everyday **sysadmin scripts** for backups, user onboarding and Windows PC health checks.

It runs on one cloud server — on **AWS or Azure**, your choice — that is **created with Terraform**, **configured with Ansible**, runs everything
in **Docker Compose**, and is tested and scanned on every push with **GitHub Actions + Trivy**.

![status page](docs/status-page.png)

## Why I built it

In my IT support job the first question on every ticket was *"is it just me, or is it down for everyone?"*.
This project answers that question automatically, and brings together everything I have practised:
Linux administration, networking checks, scripting, infrastructure as code, configuration management,
containers, CI/CD and monitoring.

## Architecture

```
GitHub push ──► GitHub Actions: ruff + pytest │ terraform validate │ ansible-lint │ shellcheck
                        │
                        └─► docker build ─► Trivy scan ─► push image to GHCR

Terraform ──► AWS EC2 (me-central-1)  or  Azure VM (UAE North)
              Ubuntu 24.04, firewall (Security Group / NSG) open only to the admin IP
                        │
Ansible   ──► harden server (no root/password SSH, UFW, fail2ban, auto updates)
              install Docker ─► docker compose up ─► nightly backup cron
                        │
          ┌─────────────┴────────────────────────────────────────┐
          │  status app (FastAPI)  ──/metrics──► Prometheus ──► Grafana
          │  node-exporter (CPU / RAM / disk) ──►   + alert rules       │
          └──────────────────────────────────────────────────────┘
```

## What's inside

| Folder | What it does | Skills |
|---|---|---|
| `app/` | FastAPI status page. Checks every target in `targets.yml` (HTTP status, TCP port, DNS lookup) every 30s, shows UP/DOWN, exposes Prometheus metrics | Python, networking, HTTP/TCP/DNS |
| `monitoring/` | Prometheus scrape config + alerts: service down, slow service, disk < 15%, CPU > 85% | Prometheus, Grafana, alerting |
| `docker-compose.yml` | App + Prometheus + Grafana + node-exporter | Docker, Docker Compose |
| `Dockerfile` | Multi-stage build, runs as non-root, built-in health check | Container security |
| `terraform/aws/` | EC2 in the UAE region, security group locked to the admin IP, encrypted disk, IMDSv2 | Terraform, AWS (EC2, SG, key pair) |
| `terraform/azure/` | The same server on Azure: resource group, VNet + subnet, NSG locked to the admin IP, public IP, Ubuntu VM with SSH key only | Terraform, Azure (VM, VNet, NSG) |
| `ansible/` | Admin user, SSH hardening, UFW firewall, fail2ban, Docker, deploy, backup cron | Ansible, Linux hardening |
| `scripts/backup.sh` | Nightly backup of config + Grafana data, keeps 7 copies, optional off-site copy to AWS S3 or Azure Blob Storage | Bash, backups (3-2-1) |
| `scripts/onboard-users.sh` | Creates Linux accounts for new staff from a CSV, temp password, forced change at first login | User & access management |
| `scripts/Get-PCHealthReport.ps1` | Windows PC report: CPU, RAM, disk space, uptime, last update, key services → HTML | PowerShell, help desk |
| `.github/workflows/ci.yml` | Lint + tests, Terraform/Ansible/ShellCheck checks, image build, Trivy scan, push to GHCR | CI/CD, DevSecOps |

## Run it locally (2 minutes)

```bash
docker compose up -d --build
# status page → http://localhost:8000
# Grafana     → http://localhost:3000  (admin / change-me)
# Prometheus  → http://localhost:9090/alerts
```

Add or remove services by editing `app/targets.yml` — no code changes and no rebuild needed.

## Deploy to the cloud (AWS or Azure)

```bash
# pick one: aws (needs `aws configure`) or azure (needs `az login`)
CLOUD=aws

cd terraform/$CLOUD
terraform init
terraform apply -var="admin_cidr=$(curl -s ifconfig.me)/32"

cd ../../ansible
cp inventory.ini.example inventory.ini   # put the public_ip from terraform output
ansible-galaxy collection install community.general
ansible-playbook -i inventory.ini site.yml

# when finished, avoid charges:
cd ../terraform/$CLOUD && terraform destroy
```

The Ansible playbook is the same for both clouds — it only needs an Ubuntu server and SSH.

## Tests

```bash
pip install -r app/requirements.txt pytest ruff
ruff check app tests && pytest -q
```

The tests check the health endpoint, validate `targets.yml`, confirm that a closed port is reported as DOWN,
and that the status page and Prometheus metrics show it.

## Author

Ahmed Elgamil — DevOps & Cloud Engineer | IT Support · [LinkedIn](https://www.linkedin.com/in/ahmed-elgamil-devops) · [GitHub](https://github.com/ahmed-elgamil-devops)
