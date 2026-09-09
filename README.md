# Ecom Platform — Hands-on SRE Practice Infra

Real, running AWS e-commerce platform built for hands-on Senior SRE prep. **Ephemeral by design** — built, exercised for ~1 day, then fully torn down. Budget hard cap: ₹300/day.

> Jira tracking: project `EP` at the Ecom Platform Jira space. Every deploy step below should correspond to something you could file/reference as a Jira ticket if it were a real team.

## Status

🚧 Build in progress — started 2026-09-09/10. See section checklist below.

## Architecture at a glance

- **App:** e-commerce — colorful frontend, functioning backend, MySQL.
- **Clusters:** 2× self-hosted k3s on EC2 (`t3.small`) — **prod** (1 server + 1 agent) and **non-prod** (1 node, hosting `dev`/`qa`/`staging` namespaces).
- **CI/CD:** GitHub Actions — hosted runners for build/test/Trivy scan, **self-hosted runner** for deploy (private access to k3s).
- **Registry:** AWS ECR.
- **Secrets:** AWS Secrets Manager → synced into cluster via External Secrets Operator.
- **Ingress:** Kong Ingress Controller in-cluster, fronted by AWS NLB via AWS Load Balancer Controller.
- **Database:** shared RDS MySQL (`db.t3.micro`, prod + staging logical DBs); dev/qa use an in-cluster MySQL pod.
- **DNS/TLS:** Cloudflare (free tier) — actually provisioned. Route53-equivalent documented as reference only.
- **Monitoring:** Prometheus + Grafana + Alertmanager, CPU-alert → Jira ticket automation via a custom webhook-receiver.
- **IaC:** Terraform (VPC/EC2/RDS/S3/ECR/IAM/Secrets Manager).
- **Deploys:** Helm, per-environment values. v1→v2 rolling update, v2→v3 blue-green practice.

## Table of contents

1. [Prerequisites](#prerequisites)
2. [Terraform remote-state bootstrap](#terraform-remote-state-bootstrap)
3. [Core infrastructure (Terraform)](#core-infrastructure-terraform)
4. [k3s cluster bring-up](#k3s-cluster-bring-up)
5. [Application build & local test](#application-build--local-test)
6. [Helm deploys](#helm-deploys)
7. [CI/CD pipeline (GitHub Actions)](#cicd-pipeline-github-actions)
8. [Kong Ingress + AWS Load Balancer Controller](#kong-ingress--aws-load-balancer-controller)
9. [Monitoring + Jira alert automation](#monitoring--jira-alert-automation)
10. [Rolling update procedure (v1→v2)](#rolling-update-procedure-v1v2)
11. [Blue-green procedure (v2→v3)](#blue-green-procedure-v2v3)
12. [Route53 reference (not provisioned)](#route53-reference-not-provisioned)
13. [Teardown — full deletion](#teardown--full-deletion)

---

## Prerequisites

- AWS CLI configured with an account that has admin-ish access (this is a personal practice account)
- Terraform >= 1.7
- kubectl, helm, docker, git installed locally
- A Cloudflare account (free tier) with a domain
- Jira Cloud account (already set up — space `EP`)

## Terraform remote-state bootstrap

Creates the S3 bucket + DynamoDB lock table that all other Terraform in this repo stores its state in. Uses **local** state itself (chicken-and-egg — nothing can point at a backend that doesn't exist yet).

```
cd terraform/bootstrap
terraform init
terraform plan
terraform apply
```

Resources created: S3 bucket `ecom-platform-tfstate-<account-id>` (versioned, AES256-encrypted, all public access blocked), DynamoDB table `ecom-platform-tflock` (pay-per-request billing — no idle cost).

Outputs (`tfstate_bucket`, `tflock_table`) feed the backend config for `terraform/main`.

## Core infrastructure (Terraform)

All commands below run from `terraform/main`. First time only, copy `terraform.tfvars.example` to `terraform.tfvars` and set `admin_cidr` to your own public IPv4 (`/32`) — get it with:
```
(Invoke-WebRequest -Uri "https://api.ipify.org").Content
```

```
cd terraform/main
terraform init
terraform plan
terraform apply
```

### Networking (done)

1 VPC (`10.20.0.0/16`), 2 public subnets across 2 AZs (`ap-south-1a`/`1b` — required even for a single-AZ RDS instance, which needs a subnet group spanning ≥2 AZs), 1 Internet Gateway, 1 public route table.

**No NAT Gateway** — deliberate cost tradeoff (~$32/mo alone would blow the ₹300/day cap). All k3s nodes sit in public subnets with public IPs; isolation comes entirely from security groups, not network placement:
- `k3s-node` SG: SSH (22) and kube-API (6443) restricted to `admin_cidr` only; HTTP/HTTPS (80/443) open to the world (arrives via the NLB); all traffic between nodes in the SG allowed (covers flannel VXLAN, kubelet, NodePort range without hand-enumerating every k3s-internal port).
- `rds` SG: MySQL (3306) only from the `k3s-node` SG.

Public subnets are tagged `kubernetes.io/role/elb = 1` so AWS Load Balancer Controller can auto-discover them later.

### IAM + ECR

*(filled in as we build)*

### RDS + Secrets Manager

*(filled in as we build)*

### EC2 (k3s nodes)

*(filled in as we build)*

## k3s cluster bring-up

*(filled in as we build)*

## Application build & local test

*(filled in as we build)*

## Helm deploys

*(filled in as we build)*

## CI/CD pipeline (GitHub Actions)

*(filled in as we build)*

## Kong Ingress + AWS Load Balancer Controller

*(filled in as we build)*

## Monitoring + Jira alert automation

*(filled in as we build)*

## Rolling update procedure (v1→v2)

*(filled in as we build)*

## Blue-green procedure (v2→v3)

*(filled in as we build)*

## Route53 reference (not provisioned)

*(filled in as we build — documented only, not applied)*

## Teardown — full deletion

**Standing requirement: this section must stay complete and accurate throughout the build — nothing should keep billing after the practice day ends.**

Teardown order matters — generally the reverse of build order (delete the things that *depend on* other things first). This section is appended to as each part of the build is added.

### 1. Terraform-managed resources (core infra — VPC/EC2/RDS/ECR/IAM/Secrets Manager)

Destroys everything in `terraform/main` in one shot (Terraform handles dependency order automatically — e.g. EC2/RDS before their security groups, subnets before the VPC):

```
cd terraform/main
terraform destroy
```

Currently covers: VPC, 2 subnets, IGW, route table, 2 security groups + their rules. More resources will be added to this same destroy as the build progresses — nothing extra to run per-phase, this one command always tears down everything `terraform/main` currently manages.

### 2. Terraform remote-state bootstrap (destroy LAST — after everything above, since core infra's state lives here)

```
cd terraform/bootstrap
terraform destroy
```

⚠️ This deletes the state bucket/lock table itself — only run this after `terraform/main`'s destroy has succeeded and you're fully done with the whole project, not between sessions.

### 3. GitHub repo

Not billed, but if you want to remove it once the practice is over:
```
gh repo delete newhorizon1796/ecom-platform --yes
```
