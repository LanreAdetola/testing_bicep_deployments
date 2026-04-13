# Azure IaC — Bicep + GitHub Actions

> A single `az deployment group create` that stands up a container-ready platform on Azure — registry, runtime, secrets store, storage, and monitoring — with OIDC-authenticated CI/CD and zero long-lived credentials.

**Stack:** Bicep · Azure Container Apps · Key Vault · GitHub Actions (OIDC) · Azure Monitor

**Status:** The deployment is not permanently running — resources are torn down between sessions to avoid costs. Redeploy with `az deployment group create` using the steps below.

## What it deploys

```text
GitHub Actions (OIDC)
  │
  ▼
main.bicep (orchestrator)
  │
  ├── modules/log-analytics.bicep
  │     └─ Log Analytics Workspace ── ingestion backend for Container Apps logs
  │
  ├── modules/storage.bicep
  │     └─ Storage Account (Standard LRS) ── blob/table/queue storage, TLS 1.2 enforced
  │
  ├── modules/container-registry.bicep
  │     └─ Azure Container Registry (Basic) ── private image registry, admin user disabled
  │
  ├── modules/container-apps.bicep
  │     ├─ Container Apps Environment ── serverless hosting plane, wired to Log Analytics
  │     └─ Container App ── runs mcr.microsoft.com/k8se/quickstart, system-assigned identity
  │
  ├── modules/key-vault.bicep
  │     └─ Key Vault (RBAC, soft-delete) ── stores storage key; Container App has Secrets User role
  │
  └── modules/monitoring.bicep
        └─ Metric Alert ── fires when HTTP 5xx count exceeds 5 in a 15-minute window
```

## Azure services used

- **Log Analytics Workspace** — free up to 5 GB/month ingestion. Required dependency for Container Apps environment logging.
- **Storage Account (Standard LRS)** — pay-per-use, negligible at low volume. General-purpose storage with the account key rotated into Key Vault.
- **Azure Container Registry (Basic)** — included storage allowance of 10 GiB. Holds container images so deployments pull from a private registry instead of public Docker Hub.
- **Container Apps Environment + Container App** — free grant of 2 million requests and 180,000 vCPU-seconds/month. Serverless container hosting with built-in scaling, no cluster management.
- **Key Vault (Standard)** — 10,000 transactions/month free. Centralizes secrets from day one so nothing sensitive lives in environment variables or config files.
- **Azure Monitor Metric Alert** — free for up to 10 alert rules. Catches 5xx spikes before users report them.

## Prerequisites

1. **Azure subscription** — a free trial works for everything in this template.
2. **Azure CLI** (>= 2.61) with the Bicep CLI installed (`az bicep install`).
3. **A resource group** — create one if it doesn't exist:

   ```bash
   az group create --name rg-bicep-demo --location eastus
   ```

4. **Entra ID app registration with OIDC federated credentials** — this replaces the old service-principal-with-secret approach. Follow the setup instructions in the comments at the top of `.github/workflows/deploy.yml`.
5. **Role assignments on the resource group** — the app registration needs **Contributor** (to create resources) and **Role Based Access Control Administrator** (to assign the Key Vault Secrets User role to the Container App's managed identity). Without both, the deployment will fail mid-way with a permissions error.
6. **GitHub repository secrets** (four values):

   | Secret                 | Value                                       |
   |------------------------|---------------------------------------------|
   | `AZURE_CLIENT_ID`      | App (client) ID from the app registration   |
   | `AZURE_TENANT_ID`      | Entra ID tenant (directory) ID              |
   | `AZURE_SUBSCRIPTION_ID`| Target Azure subscription ID                |
   | `AZURE_RG`             | Name of the resource group                  |

## How to deploy

1. **Fork** this repository (or push it to your own GitHub account).
2. **Create the Entra ID app registration** and add two federated credentials — one for the `main` branch, one for pull requests. Grant the role assignments listed in prerequisites.
3. **Add the four secrets** listed above under Settings → Secrets and variables → Actions.
4. **Push to main** — the workflow validates the template, then deploys it. The Container App URL is printed at the end of the deploy job.
5. **Open a pull request** — the workflow runs `az bicep build` and `az deployment group validate` (preflight what-if) without deploying anything, so you catch errors before they hit production.

To deploy locally without CI:

```bash
az deployment group create \
  --resource-group rg-bicep-demo \
  --template-file main.bicep \
  --parameters main.bicepparam
```

## GitHub Actions workflow

The workflow file (`.github/workflows/deploy.yml`) has two jobs:

- **validate** — runs on every push and every pull request. Builds the Bicep file to check for syntax and linter errors, then authenticates via OIDC and runs `az deployment group validate` to catch ARM-level issues (invalid SKUs, naming collisions, quota limits) without actually creating resources.
- **deploy** — runs only on pushes to `main`, after `validate` succeeds. Calls `az deployment group create`, captures the deployment outputs as JSON, extracts the Container App URL, and prints it to the workflow summary.

Both jobs authenticate using OpenID Connect (OIDC) federated credentials — there is no `AZURE_CREDENTIALS` JSON blob stored as a secret.

## Design decisions

**Container Apps over VMs or AKS.** The goal is a container platform that costs nothing at low traffic and scales without ops work. Azure Container Apps sits on top of Kubernetes but abstracts away node pools, ingress controllers, and certificate management. A VM would require patching and manual scaling. AKS would require cluster-level configuration that isn't justified until you have multiple teams sharing a cluster. Container Apps gives you per-app scaling rules, built-in HTTPS, and a consumption billing model — the right trade-off for a single-app or small-service deployment.

**Key Vault from day one, with RBAC.** The original template stored a storage account key in Key Vault using access policies — a pattern that works but doesn't compose well. Access policies are a flat list baked into the vault resource, and they require knowing object IDs at deploy time. RBAC authorization (`enableRbacAuthorization: true`) delegates access control to Azure's standard role-assignment model, which means the Container App's managed identity gets `Key Vault Secrets User` through a normal role assignment — no special Key Vault configuration, no objectId bookkeeping. Soft-delete is enabled explicitly even though it's the default, because being explicit about data-loss protection is worth the one extra line.

**OIDC over service principal secrets.** The previous workflow used a `AZURE_CREDENTIALS` secret containing a service principal's client ID and client secret. That secret has an expiration date (typically 1-2 years), and if it leaks, anyone with the JSON blob can authenticate as that principal from anywhere. OIDC federated credentials eliminate the secret entirely: GitHub's OIDC provider issues a short-lived token scoped to a specific repository and branch, and Azure validates it directly. There is nothing to rotate, nothing to leak, and the blast radius of a compromised workflow is limited to the specific branch or PR entity type you configured. The only downside is a slightly more involved one-time setup in Entra ID.

**What I'd add next.** VNet integration for the Container Apps environment so the app, Key Vault, and storage account communicate over private endpoints instead of the public internet. A second parameter file (`main.prod.bicepparam`) and a GitHub environment with required reviewers gating production deploys. A `what-if` comment posted to PRs showing exactly which resources will change. And eventually, if the team grows beyond one or two people, a Terraform rewrite — not because Bicep is insufficient, but because Terraform's state-locking and multi-cloud provider ecosystem become more valuable when infrastructure is owned by a dedicated platform team rather than the app developers who built it.
