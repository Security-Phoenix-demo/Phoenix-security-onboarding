# Microsoft Azure Defender On-Boarding Toolkit

This folder helps you enable **Microsoft Defender for Cloud** (Standard tier) and integrate **Microsoft Defender for Endpoint** across one or more Azure subscriptions so Phoenix Security can ingest your security alerts & vulnerabilities.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [What the Script Does](#what-the-script-does)
4. [Asset Enumeration & Summary](#asset-enumeration--summary)
5. [Phoenix Integration Steps](#phoenix-integration-steps)
6. [Cleanup](#cleanup)
7. [Troubleshooting](#troubleshooting)
8. [References](#references)

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

## Asset Enumeration & Summary

Need an at-a-glance inventory of every Azure resource?  Two helper scripts give you per-subscription counts and a machine-readable CSV without writing any code.

### PowerShell (all-in-one)

`azure/enumerate_resources_2.ps1` enumerates every subscription you can access via the **Az PowerShell** module, shows a progress bar, prints a nicely formatted breakdown, and writes a CSV.

```powershell
# interactive session
cd azure
./enumerate_resources_2.ps1                               # CSV → AzureResourceSummary-YYYYMMDDHHMMSS.csv

# custom output path
./enumerate_resources_2.ps1 -OutputCsv C:\temp\summary.csv
```

The CSV contains four columns:

| SubscriptionName | SubscriptionId | ResourceType | Count |
|------------------|---------------|--------------|-------|
| My Dev Subs      | 1111-…        | TOTAL        | 256   |
| My Dev Subs      | 1111-…        | Microsoft.Compute/virtualMachines | 42 |
| …                | …             | …            | …    |

### Bash (parse TSV)

`azure/summarize_resource_counts.sh` expects the **TSV output** produced by `list_assets-azure.sh` (or any Azure Resource Graph query via `az graph query`).  It prints the same summary and writes an identical CSV.

```bash
# 1) Produce a TSV (example using Resource Graph)
az graph query -q "Resources | project id, name, type, location" --output tsv \
  > azure_assets.tsv

# 2) Summarise
cd azure
./summarize_resource_counts.sh azure_assets.tsv                 # auto-names CSV
./summarize_resource_counts.sh azure_assets.tsv mySummary.csv   # custom name

# Or stream directly
./list_assets-azure.sh | ./summarize_resource_counts.sh - output.csv
```

Both PowerShell and Bash versions generate **identical CSV files**, so you can pick whichever shell is more convenient.

---

## What the Script Does

### Defender Plans Enabled

| Plan (CLI name) | Covers |
|-----------------|--------|
| `VirtualMachines` | Defender for Servers (includes MDE integration) |
| `AppServices`