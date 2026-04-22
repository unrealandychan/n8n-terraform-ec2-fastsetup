<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=6,11,20&height=160&section=header&text=n8n--terraform--ec2--fastsetup&fontSize=38&fontColor=ffffff&fontAlignY=38&desc=Fast+n8n+deployment+on+AWS+EC2+via+Terraform&descAlignY=58&descSize=14" alt="Header"/>

[![Stars](https://img.shields.io/github/stars/unrealandychan/n8n-terraform-ec2-fastsetup?style=for-the-badge&logo=github&color=f78166&logoColor=white&labelColor=0d1117)](https://github.com/unrealandychan/n8n-terraform-ec2-fastsetup/stargazers)
[![Forks](https://img.shields.io/github/forks/unrealandychan/n8n-terraform-ec2-fastsetup?style=for-the-badge&logo=github&color=79c0ff&logoColor=white&labelColor=0d1117)](https://github.com/unrealandychan/n8n-terraform-ec2-fastsetup/network/members)
[![Language](https://img.shields.io/badge/HCL-7B42BC?logo=terraform&style=for-the-badge&logoColor=white&labelColor=0d1117)](https://github.com/unrealandychan/n8n-terraform-ec2-fastsetup)
[![n8n](https://img.shields.io/badge/n8n-Automation-ea4b71?style=for-the-badge&logo=n8n&logoColor=white&labelColor=0d1117)](https://n8n.io/)

</div>

---

# n8n on AWS EC2 — Terraform Fast Setup

> **One-command deployment** of a production-ready [n8n](https://n8n.io) workflow-automation server on AWS EC2, behind a Traefik reverse proxy with automatic TLS (Let's Encrypt).

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Variables Reference](#variables-reference)
- [Quick Start](#quick-start)
  - [1 · Clone the repository](#1--clone-the-repository)
  - [2 · Configure variables](#2--configure-variables)
  - [3 · Deploy](#3--deploy)
  - [4 · Point your DNS](#4--point-your-dns)
  - [5 · Access n8n](#5--access-n8n)
- [SSH Access](#ssh-access)
- [Upgrading n8n](#upgrading-n8n)
- [Backup & Restore](#backup--restore)
- [Security Considerations](#security-considerations)
- [Cost Estimate](#cost-estimate)
- [Troubleshooting](#troubleshooting)
- [Destroying Resources](#destroying-resources)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This Terraform project provisions all the AWS infrastructure required to run n8n in production:

| Layer | Technology |
|---|---|
| Cloud provider | AWS (configurable region) |
| Compute | EC2 (Amazon Linux 2) |
| Networking | VPC, public subnet, Internet Gateway, route table |
| TLS termination | Traefik v2 + Let's Encrypt (ACME TLS challenge) |
| Container runtime | Docker + Docker Compose v2 |
| Workflow automation | n8n (latest) |
| SSH key management | Auto-generated RSA-4096 key pair (saved locally) |

---

## Architecture

```
                        ┌──────────────────────────────────────┐
                        │            AWS Region                │
                        │                                      │
   Internet ──HTTPS──►  │  ┌──────── Public Subnet ────────┐  │
                        │  │                                │  │
                        │  │  ┌──────────────────────────┐  │  │
                        │  │  │  EC2 Instance             │  │  │
                        │  │  │                          │  │  │
                        │  │  │  ┌────────────────────┐  │  │  │
                        │  │  │  │  Traefik  :80/:443 │  │  │  │
                        │  │  │  │  (TLS termination) │  │  │  │
                        │  │  │  └────────┬───────────┘  │  │  │
                        │  │  │           │ localhost     │  │  │
                        │  │  │  ┌────────▼───────────┐  │  │  │
                        │  │  │  │  n8n       :5678   │  │  │  │
                        │  │  │  │  (bound to 127.0.1)│  │  │  │
                        │  │  │  └────────────────────┘  │  │  │
                        │  │  └──────────────────────────┘  │  │
                        │  └────────────────────────────────┘  │
                        │                                      │
                        │  Security Group: 22, 80, 443 inbound │
                        └──────────────────────────────────────┘
```

Traefik handles HTTP→HTTPS redirects and obtains a free TLS certificate from Let's Encrypt automatically on first start. The n8n container is **not** exposed to the public internet directly — only Traefik routes traffic to it on localhost.

---

## Features

- ✅ Fully automated end-to-end provisioning with a single `terraform apply`
- ✅ Auto-generated RSA-4096 SSH key pair — no manual key management
- ✅ Free automatic TLS via Let's Encrypt (renewed automatically by Traefik)
- ✅ HTTP → HTTPS redirect enforced by Traefik
- ✅ HSTS, XSS protection, content-type sniffing prevention headers set
- ✅ n8n data persisted in named Docker volumes (survives container restarts)
- ✅ Configurable AWS region, instance type, domain, subdomain, and timezone

---

## Prerequisites

| Tool | Minimum version | Install guide |
|---|---|---|
| [Terraform CLI](https://developer.hashicorp.com/terraform/install) | 1.3+ | `brew install terraform` / official installer |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | 2.x | `brew install awscli` |
| AWS credentials | — | `aws configure` or environment variables |
| A registered domain name | — | AWS Route 53, Namecheap, etc. |

> **AWS credentials** must have permissions to manage EC2, VPC, IAM key pairs, and security groups.  
> For least-privilege, attach the `AmazonEC2FullAccess` managed policy to the deploying IAM user/role (or use a custom policy scoped to only the resources created here).

---

## Variables Reference

All variables are defined in `variables.tf`. You can override them via a `terraform.tfvars` file (recommended) or with `-var` flags.

| Variable | Description | Default |
|---|---|---|
| `project_name` | Prefix applied to all AWS resource names and the SSH key file | `my-project` |
| `instance_type` | EC2 instance type | `t2.micro` |
| `ssl_email` | Email address used by Let's Encrypt for certificate notifications | `your-email@example.com` |
| `domain_name` | Root domain (e.g. `example.com`) | `example.com` |
| `subdomain` | Subdomain for n8n (e.g. `n8n` → `n8n.example.com`) | `n8n` |
| `timezone` | [IANA timezone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) for n8n (e.g. `America/New_York`) | `UTC` |
| `tags` | Map of tags applied to all AWS resources | `{Environment="dev", Project="my-project", Terraform="true"}` |

### Recommended instance types

| Workload | Instance type | vCPU | RAM |
|---|---|---|---|
| Personal / testing | `t2.micro` (Free Tier eligible) | 1 | 1 GB |
| Small team | `t3.small` | 2 | 2 GB |
| Production team | `t3.medium` | 2 | 4 GB |

---

## Quick Start

### 1 · Clone the repository

```bash
git clone https://github.com/unrealandychan/n8n-terraform-ec2-fastsetup.git
cd n8n-terraform-ec2-fastsetup
```

### 2 · Configure variables

Create a `terraform.tfvars` file (this file is git-ignored by default — **never commit secrets**):

```hcl
# terraform.tfvars
project_name  = "n8n-prod"
instance_type = "t3.small"

ssl_email   = "you@example.com"
domain_name = "example.com"
subdomain   = "n8n"
timezone    = "America/New_York"

tags = {
  Environment = "production"
  Project     = "n8n-prod"
  Terraform   = "true"
}
```

### 3 · Deploy

```bash
# Authenticate with AWS
aws configure          # or set AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY env vars

# Initialise Terraform providers
terraform init

# Preview what will be created
terraform plan

# Deploy (type 'yes' when prompted)
terraform apply
```

Terraform will output your instance's public IP address:

```
Outputs:

ssh_connection_string = "ssh -i n8n-prod-key.pem ec2-user@<PUBLIC_IP>"
```

> The SSH private key is saved as `<project_name>-key.pem` in the current directory with permissions `400`. Keep this file secure and do not commit it to version control.

### 4 · Point your DNS

Create an **A record** in your DNS provider pointing your subdomain to the EC2 public IP:

| Type | Name | Value | TTL |
|---|---|---|---|
| A | `n8n` | `<PUBLIC_IP>` | 300 |

> DNS propagation typically takes 1–5 minutes for low TTLs. Let's Encrypt certificate issuance happens on first HTTPS request after DNS resolves.

### 5 · Access n8n

Once DNS has propagated, open your browser and navigate to:

```
https://n8n.example.com
```

n8n will guide you through creating the first owner account on the initial visit.

---

## SSH Access

The Terraform output contains the full SSH command:

```bash
ssh -i <project_name>-key.pem ec2-user@<PUBLIC_IP>
```

Example:

```bash
ssh -i n8n-prod-key.pem ec2-user@54.123.45.67
```

Once connected, the n8n project files are located at:

```
/home/ec2-user/n8n/
├── .env
└── docker-compose.yml
```

View running containers:

```bash
docker ps
```

View n8n logs:

```bash
docker-compose -f /home/ec2-user/n8n/docker-compose.yml logs -f n8n
```

View Traefik logs:

```bash
docker-compose -f /home/ec2-user/n8n/docker-compose.yml logs -f traefik
```

---

## Upgrading n8n

SSH into the instance and run:

```bash
cd /home/ec2-user/n8n

# Pull the latest n8n image
docker-compose pull n8n

# Recreate the container with the new image (zero-downtime restart)
docker-compose up -d --no-deps n8n
```

> n8n data is stored in the `n8n_data` Docker volume and is **not** affected by image upgrades.

---

## Backup & Restore

### Backup

n8n workflow data lives in the `n8n_data` Docker volume. To create a backup archive:

```bash
# SSH into the EC2 instance
ssh -i n8n-prod-key.pem ec2-user@<PUBLIC_IP>

# Create a compressed backup of the n8n data volume
docker run --rm \
  -v n8n_data:/data \
  -v /tmp:/backup \
  alpine tar czf /backup/n8n-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /data .

# Copy the backup to your local machine (run from your local terminal)
scp -i n8n-prod-key.pem ec2-user@<PUBLIC_IP>:/tmp/n8n-backup-*.tar.gz .
```

### Restore

```bash
# Copy backup file to the instance
scp -i n8n-prod-key.pem n8n-backup-YYYYMMDD-HHMMSS.tar.gz ec2-user@<PUBLIC_IP>:/tmp/

# SSH in and restore
ssh -i n8n-prod-key.pem ec2-user@<PUBLIC_IP>

docker-compose -f /home/ec2-user/n8n/docker-compose.yml stop n8n

docker run --rm \
  -v n8n_data:/data \
  -v /tmp:/backup \
  alpine sh -c "rm -rf /data/* && tar xzf /backup/n8n-backup-YYYYMMDD-HHMMSS.tar.gz -C /data"

docker-compose -f /home/ec2-user/n8n/docker-compose.yml start n8n
```

> **Tip:** Automate backups with a cron job on the EC2 instance and upload archives to S3 using the AWS CLI (`aws s3 cp`).

---

## Security Considerations

| Area | Current behaviour | Production recommendation |
|---|---|---|
| SSH access | Port 22 open to `0.0.0.0/0` | Restrict `cidr_blocks` in the security group to your static IP(s) |
| n8n port | Bound to `127.0.0.1:5678` (not publicly exposed) | ✅ Already secure |
| TLS | Automatic via Let's Encrypt | ✅ Already enabled |
| HSTS | Configured via Traefik middleware | ✅ Already enabled |
| SSH key | Auto-generated, stored locally as `*.pem` | Add to `.gitignore`; store in AWS Secrets Manager or 1Password |
| Traefik dashboard | API insecure mode enabled (`--api.insecure=true`) | Disable or password-protect in production |
| n8n authentication | Owner account created on first login | Enable [n8n user management](https://docs.n8n.io/user-management/) |

### Restrict SSH ingress (recommended)

In `main.tf`, update the SSH ingress rule to your IP:

```hcl
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["<YOUR_IP>/32"]   # Replace with your public IP
}
```

---

## Cost Estimate

Costs are approximate for **us-east-1** (prices vary by region). See [AWS pricing](https://aws.amazon.com/ec2/pricing/on-demand/) for exact figures.

| Resource | `t2.micro` (Free Tier) | `t3.small` |
|---|---|---|
| EC2 compute | $0 (750 hrs/month Free Tier) | ~$15/month |
| EBS storage (8 GB gp2) | $0 (30 GB Free Tier) | ~$0.80/month |
| Data transfer | $0 (first 1 GB) | ~$0.09/GB after 1 GB |
| Elastic IP | Free while attached | Free while attached |
| **Total (estimated)** | **$0 (Free Tier)** | **~$16/month** |

> Free Tier eligibility applies only to new AWS accounts for the first 12 months.

---

## Troubleshooting

### n8n is not accessible in the browser

1. Verify DNS resolution: `nslookup n8n.example.com` should return the EC2 public IP.
2. Check the containers are running: SSH in and run `docker ps`.
3. Check Traefik logs for certificate errors: `docker-compose -f /home/ec2-user/n8n/docker-compose.yml logs traefik`.
4. Ensure ports 80 and 443 are open in the security group.
5. Let's Encrypt rate limits: if you hit certificate issuance limits, wait 1 hour and retry.

### `terraform apply` fails with permission errors

Ensure your AWS IAM user/role has the required permissions:
- `ec2:*` for VPC, subnets, security groups, instances, key pairs
- `iam:CreateServiceLinkedRole` (may be required for first-time VPC creation)

Run `aws sts get-caller-identity` to confirm the correct account is active.

### SSH connection refused

- The instance takes ~2–3 minutes after `terraform apply` to finish the `user_data` bootstrap script.
- Verify the correct key file and path: `ssh -i <project_name>-key.pem ec2-user@<IP>`.
- Verify port 22 is open in the security group.

### Docker Compose services fail to start

SSH in and check logs:

```bash
docker-compose -f /home/ec2-user/n8n/docker-compose.yml logs
```

Ensure the `.env` file at `/home/ec2-user/n8n/.env` contains the correct values.

### Traefik dashboard is accessible publicly

Traefik's insecure API (`--api.insecure=true`) exposes the dashboard on port 8080. It is not exposed in the security group by default, but you should disable it in production by removing `--api.insecure=true` from the Docker Compose Traefik command and managing access via Traefik's secure API.

---

## Destroying Resources

To tear down all AWS resources created by this project:

```bash
terraform destroy
```

Type `yes` when prompted. This will permanently delete:
- The EC2 instance (and all data on it)
- The VPC, subnets, Internet Gateway, and route tables
- The security group
- The SSH key pair in AWS

> ⚠️ **Back up your n8n workflows before destroying.** Docker volumes on the instance will be lost.

---

## Contributing

Contributions are welcome! Please open an issue to discuss the change you'd like to make before submitting a pull request.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-improvement`
3. Commit your changes: `git commit -m 'feat: add my improvement'`
4. Push the branch: `git push origin feature/my-improvement`
5. Open a pull request

---

## License

This project is licensed under the [MIT License](LICENSE).