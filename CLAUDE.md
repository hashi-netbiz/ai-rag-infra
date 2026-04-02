# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Terraform IaC repository that deploys cloud-native infrastructure for an AI RAG application on AWS. Infrastructure is organized into independent Terraform modules, each with its own remote state in S3.

## Terraform Workflow

Each module is initialized and applied independently. Navigate into the module directory before running commands:

```bash
# Initialize with remote state backend
terraform init -backend-config=state.config

# Plan changes (use the appropriate tfvars file for the module)
terraform plan -var-file=<module>.tfvars    # e.g., terraform plan -var-file=vpc.tfvars
terraform plan -var-file=../global.tfvars   # for global modules without their own tfvars

# Apply
terraform apply -var-file=<module>.tfvars

# Format and validate
terraform fmt -recursive
terraform validate
```

**Deployment order matters** — modules depend on each other via remote state:
1. `global/s3` — must be first (creates the state bucket all other modules use)
2. `global/ecr`, `global/iam` — independent, can run in parallel
3. `dev/vpc` — networking, no EKS dependency
4. `dev/eks` — depends on VPC remote state (reads subnet IDs)

## Architecture

```
global/s3    → S3 bucket for Terraform state (ai-rag-terraform-state, us-east-1)
global/ecr   → ECR repositories (one per GitHub repo in github_repos variable)
global/iam   → GitHub Actions OIDC provider + IAM role for CI/CD (ECR push/pull)
dev/vpc      → VPC (10.0.0.0/16), 2 private + 2 public subnets across us-east-1a/b, single NAT
dev/eks      → EKS 1.33 cluster ("dev-main"), 2×t3.large nodes, ArgoCD, AWS LBC, Image Updater
```

**Cross-module state references:** `dev/eks` reads VPC outputs (subnet IDs, VPC ID) from the `dev/vpc` remote state via `data.tf`. Do not rename VPC outputs without updating `dev/eks/data.tf`.

**GitOps flow:** GitHub Actions → ECR push → ArgoCD Image Updater detects new tag → updates deployment → ArgoCD syncs cluster. The Image Updater uses a shell auth script (`auth.sh`) to obtain ECR tokens (10h expiry).

## Key Patterns

- **Module structure:** Every module has `providers.tf`, `state.tf`, `variables.tf`, and a dedicated `.tfvars` file. State keys follow `{env}/{module}/terraform.tfstate`.
- **Modules used:** `terraform-aws-modules` for VPC, ECR, and IAM (versions pinned in each `providers.tf`).
- **Pod Identity** (not IRSA) is used for IAM permissions in EKS — see `pod-Identity.tf` and the service accounts in `lbc.tf` and `image-updater.tf`.
- **tfvars files are gitignored** — the `.gitignore` excludes `*.tfvars`. The files exist locally but won't be committed.
- ArgoCD is deployed in insecure mode (HTTP) — configured via `values/argocd.yaml`.
- Node group is pinned to a single AZ to avoid cross-AZ data transfer charges.

## AWS Context

- Region: `us-east-1`
- Account: `424432388155`
- State bucket: `ai-rag-terraform-state`
- GitHub org: `hashi-netbiz`, repos: `ai-rag-project/backend`, `ai-rag-project/frontend`
