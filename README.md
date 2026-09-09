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

### IAM + ECR (done)

- **ECR:** `ecom-platform/frontend` and `ecom-platform/backend` repos, scan-on-push enabled, lifecycle policy keeps last 10 images.
- **IAM role `ecom-platform-k3s-node`** (+ matching instance profile), attached to every EC2 node. Not EKS, so no IRSA — pods needing AWS API access (AWS Load Balancer Controller, External Secrets Operator) inherit permissions from the node's instance profile via EC2 metadata. Fine at this scale; a real multi-team cluster would isolate this per-pod instead (kiam/kube2iam, or migrate to EKS+IRSA).
  - `AmazonEC2ContainerRegistryReadOnly` — pull images
  - Custom `secrets-read` policy — scoped to `secretsmanager:GetSecretValue`/`DescribeSecret` on `ecom-platform/*` secrets only
  - AWS Load Balancer Controller policy (standard upstream policy, `terraform/main/policies/alb-controller-policy.json`) — lets the controller manage the NLB fronting Kong
  - `CloudWatchAgentServerPolicy` — node-level metrics/logs alongside in-cluster Prometheus

### RDS + Secrets Manager (done)

- **RDS MySQL** `db.t3.micro`, engine 8.0, `publicly_accessible = false` (reachable only from the `k3s-node` SG, not the internet), no Multi-AZ, no backups, `skip_final_snapshot = true` — all deliberate for an ephemeral practice project, not something you'd do for a real prod DB.
- Master password auto-generated (`random_password`), stored in Secrets Manager at `ecom-platform/rds-master` — never appears in this repo or chat.
- Separate logical databases (`prod`, `staging`) are created manually via SQL once a k3s node exists to run `mysql` client from (RDS SG only allows the `k3s-node` SG, not your admin IP directly) — documented in the "Application build & local test" section once we get there.
- **Jira integration secret** at `ecom-platform/jira-integration` — Terraform creates the secret shell with a placeholder; the real `{email, api_token}` value is set manually via `aws secretsmanager put-secret-value` (never committed, never round-tripped through chat) — consumed later by the webhook-receiver for CPU-alert → Jira ticket automation.

⚠️ **If you ever paste a real API token or password into a chat/terminal session that gets logged, treat it as compromised and rotate it** — this happened once during this build (Jira token pasted into the assistant chat) and the token was regenerated as a result.

### EC2 (k3s nodes) (done)

3× `t3.small` (locked sizing — real ₹300/day budget covers this comfortably even worst-case, prioritizing "must actually run properly" over squeezing into free-tier micro instances). Ubuntu 22.04 LTS. No k3s installed via `user_data` — that's done by hand over SSH in the next section, deliberately: hands-on k3s install/join is one of the confirmed skill-gap areas this whole project exists to close.

First time only, generate an admin SSH key pair (Terraform imports only the **public** half — the private key never leaves your machine, never touches state or this repo):
```
ssh-keygen -t ed25519 -f "$HOME\.ssh\ecom-platform-admin" -C "ecom-platform-admin" -N '""'
```
Set `ssh_public_key_path` in `terraform.tfvars` to the resulting `.pub` file's full path.

| Node | Role | Cluster |
|---|---|---|
| `ecom-platform-prod-server` | k3s server | prod |
| `ecom-platform-prod-agent` | k3s agent | prod |
| `ecom-platform-nonprod-node` | k3s server (single-node) | nonprod — hosts `dev`/`qa`/`staging` namespaces |

SSH in with:
```
ssh -i ~/.ssh/ecom-platform-admin ubuntu@<public-ip>
```
(public IPs are in Terraform outputs: `prod_server_public_ip`, `prod_agent_public_ip`, `nonprod_node_public_ip`)

## k3s cluster bring-up

Installed by hand over SSH, not via `user_data` — deliberate, this is one of the hands-on skill-gap areas this project exists to close.

### Prod cluster (server + agent)

SSH into `prod_server_public_ip`, install as server (Traefik/ServiceLB disabled — using Kong + a real AWS NLB instead):
```
ssh -i ~/.ssh/ecom-platform-admin ubuntu@<prod_server_public_ip>
curl -sfL https://get.k3s.io | sh -s - server --disable traefik --disable servicelb --write-kubeconfig-mode 644
kubectl get nodes   # confirm Ready
sudo cat /var/lib/rancher/k3s/server/node-token   # save this, needed by the agent
```

In a **second terminal**, SSH into `prod_agent_public_ip` and join it using the server's **private** IP (traffic stays inside the VPC, not over the internet):
```
ssh -i ~/.ssh/ecom-platform-admin ubuntu@<prod_agent_public_ip>
curl -sfL https://get.k3s.io | K3S_URL=https://<prod_server_private_ip>:6443 K3S_TOKEN=<token from above> sh -
```

Back on the server: `kubectl get nodes` should show both nodes `Ready`.

### Non-prod cluster (single node)

Same server install command on `nonprod_node_public_ip`, standalone (no join):
```
ssh -i ~/.ssh/ecom-platform-admin ubuntu@<nonprod_node_public_ip>
curl -sfL https://get.k3s.io | sh -s - server --disable traefik --disable servicelb --write-kubeconfig-mode 644
```

Then create the `dev`/`qa`/`staging` namespaces with their quotas (manifests live in `k8s/base/namespaces/`) — paste the combined YAML via `kubectl apply -f -` in that SSH session, or `kubectl apply -f k8s/base/namespaces/` from a machine with kubeconfig access once that's set up (below). Staging gets prod-equivalent `ResourceQuota`/`LimitRange`; dev/qa get smaller ones — all sized conservatively to actually fit a shared `t3.small` (2 vCPU/2GiB total).

### Local kubectl access

k3s's self-signed server cert only covers its private IP by default — needs a `--tls-san` entry for the public IP or your local `kubectl` will fail TLS verification. On **each** node:
```
sudo sh -c 'echo "tls-san:
  - \"<node-public-ip>\"" > /etc/rancher/k3s/config.yaml'
sudo systemctl restart k3s
```

Then pull each kubeconfig via `scp` (never paste kubeconfig content into chat — it's a full-admin credential) and rewrite the server address + rename from the generic `default` context so both can coexist:
```
scp -i ~/.ssh/ecom-platform-admin ubuntu@<prod_server_public_ip>:/etc/rancher/k3s/k3s.yaml ~/.kube/ecom-prod.yaml
scp -i ~/.ssh/ecom-platform-admin ubuntu@<nonprod_node_public_ip>:/etc/rancher/k3s/k3s.yaml ~/.kube/ecom-nonprod.yaml
```
```powershell
(Get-Content ~/.kube/ecom-prod.yaml) -replace '127.0.0.1','<prod_server_public_ip>' -replace 'default','ecom-prod' | Set-Content ~/.kube/ecom-prod.yaml
(Get-Content ~/.kube/ecom-nonprod.yaml) -replace '127.0.0.1','<nonprod_node_public_ip>' -replace 'default','ecom-nonprod' | Set-Content ~/.kube/ecom-nonprod.yaml
```
```powershell
$env:KUBECONFIG = "$HOME\.kube\ecom-prod.yaml;$HOME\.kube\ecom-nonprod.yaml"
kubectl config get-contexts
kubectl config use-context ecom-prod    # or ecom-nonprod
```
(Set `KUBECONFIG` permanently via System Environment Variables so it persists across terminal sessions.)

## Application build & local test

Stack: **React (Vite) frontend, Node.js/Express backend, MySQL 8.0**. Cart is client-held; the server is the source of truth for pricing/discount math (never trust a client-supplied total).

Run the full stack locally with Docker Compose — this is the "initial local testing" step referenced elsewhere in this README (catching bugs before they ever reach CI):

```
docker compose up --build
```

- Frontend: http://localhost:5173
- Backend API: http://localhost:4000/api/products
- MySQL: localhost:3306 (seeded automatically from `app/backend/db/init.sql` on first start)

Try a full flow: add a few different products to the cart, apply discount code `WELCOME10` or `SUMMER20` at checkout, confirm the discount is applied to the **summed cart subtotal** (not just one line item) and the order total matches what you'd expect by hand.

Tear down local containers + volume when done testing:
```
docker compose down -v
```

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
