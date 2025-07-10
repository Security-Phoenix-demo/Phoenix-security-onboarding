# Microsoft Azure Defender On-Boarding Toolkit

This folder helps you enable **Microsoft Defender for Cloud** (Standard tier) and integrate **Microsoft Defender for Endpoint** across one or more Azure subscriptions so Phoenix Security can ingest your security alerts & vulnerabilities.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [What the Script Does](#what-the-script-does)
4. [Phoenix Integration Steps](#phoenix-integration-steps)
5. [Cleanup](#cleanup)
6. [Troubleshooting](#troubleshooting)
7. [References](#references)

---

## Prerequisites

* **Azure CLI** ≥ 2.45 – install via `brew install azure-cli` (macOS) or [MS docs](https://aka.ms/InstallAzureCLI).
* **Identity & Permissions**
  * Sign-in as **Owner** or **Security Admin** on each subscription you plan to onboard.
  * The account must be able to register resource providers and update Defender plans.

---

## Quick Start

```bash
cd azure
chmod +x enable_defender.sh   # one-time
./enable_defender.sh
```

The script will:

1. Verify the Azure CLI is installed & you’re signed in (`az login` if needed).
2. List all subscriptions you can access.
3. Ask whether to enable Defender for **all** subscriptions or a subset.
4. For each selected subscription:
   * Enable **Microsoft Defender for Cloud (Standard tier)** for core resource types (VMs, App Services, SQL, Storage, Kubernetes, etc.).
   * Ensure **Defender for Endpoint** (WDATP) integration is **On** for servers/VMs.

When complete you’ll see a green “Done!” message.

---

## What the Script Does

### Defender Plans Enabled

| Plan (CLI name) | Covers |
|-----------------|--------|
| `VirtualMachines` | Defender for Servers (includes MDE integration) |
| `AppServices` | Web Apps, API Apps, Functions |
| `SqlServers` / `SqlServerVirtualMachines` | Azure SQL / SQL VMs |
| `StorageAccounts` | Storage accounts data-plane protection |
| `KubernetesService` | AKS clusters |
| `ContainerRegistry` | ACR image scanning |
| `KeyVaults` | Secrets & key management |

All plans are set to **Standard** (`az security pricing create --tier Standard`).

### Defender for Endpoint Integration

`az security setting update --name WDATP --setting-value On` tells Defender for Cloud to automatically onboard VMs/servers into Microsoft Defender for Endpoint (formerly Windows Defender ATP).

---

## Phoenix Integration Steps

1. In the **Azure Portal** under *Microsoft Defender for Cloud → Environment settings*, confirm that alerts are flowing (can take ~15 min).
2. In the Phoenix Platform go to **Integrations → Scanners → Azure Defender** and click **Add Scanner**.
3. Provide:
   * **Subscription / Tenant IDs** to monitor.
   * **App Registration (Service Principal)** credentials with `SecurityReader` role at tenant root.
   * Select whether to ingest alerts, recommendations, or both.
4. Click **Create Scanner** – Phoenix will start syncing data shortly.

---

## Cleanup

To disable Defender plans & MDE integration:

```bash
# set the subscription first
az account set --subscription <SUBSCRIPTION_ID>

# downgrade each plan back to Free
for plan in VirtualMachines AppServices SqlServers SqlServerVirtualMachines StorageAccounts KubernetesService ContainerRegistry KeyVaults; do
  az security pricing create --name $plan --tier Free
done

# turn off Defender for Endpoint integration
az security setting update --name WDATP --setting-value Off
```

---

## Troubleshooting

| Issue | Resolution |
|-------|------------|
| `AuthorizationFailed` when enabling pricing | Ensure your identity is **Owner** or has `Microsoft.Security/pricings/write` permissions. |
| `az security setting` reports “not found” | Your Azure CLI version may be outdated; run `az upgrade`. |
| Defender for Endpoint onboarding fails on Linux VMs | Validate the *Log Analytics agent* or *AMA* is installed; check [MDE Linux requirements](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/linux). |

---

## References

* [Enable Microsoft Defender plans via CLI](https://learn.microsoft.com/azure/defender-for-cloud/powershell-onboarding)
* [Defender for Endpoint integration](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-endpoint)
* [Pricing](https://aka.ms/DefenderPricing) 