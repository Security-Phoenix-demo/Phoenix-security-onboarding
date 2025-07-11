# Google Cloud Security Command Center On-Boarding Toolkit

> **Purpose** – Quickly enable Security Command Center (SCC) and its key detectors across multiple Google Cloud projects, then integrate findings into the Phoenix Security platform.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Detectors Supported](#detectors-supported)
3. [Setup Options](#setup-options)
   * Shell Script
   * Terraform
4. [Asset Enumeration & Summary](#asset-enumeration--summary)
5. [Service Account & Credentials](#service-account--credentials)
6. [Phoenix Platform Integration](#phoenix-platform-integration)
7. [Troubleshooting & FAQ](#troubleshooting--faq)
8. [Cleanup](#cleanup)
9. [Costs & Quotas](#costs--quotas)
10. [References](#references)
11. [License](#license)

---

## Architecture

```text
┌──────────────────────────────┐          ┌──────────────────────────────┐
│           PROJECT A          │          │           PROJECT B          │
│  (compute, containers …)     │          │  (serverless, GKE …)         │
│                              │          │                              │
│  SCC Detectors (enabled)     │          │  SCC Detectors (enabled)     │
│  ├─ Security Health Analytics│          │  ├─ Security Health Analytics│
│  ├─ Web Security Scanner     │  ◀──────▶│  ├─ Container Threat Detect. │
│  └─ …                        │   Findings│  └─ …                        │
└─────────────┬────────────────┘          └─────────────┬────────────────┘
              │                                           │
              ▼                                           ▼
      ┌─────────────────────────────────────────────────────────┐
      │  Security Command Center (Org / Project Level)         │
      │  • Assets / Findings                                   │
      └─────────────┬───────────────────────────────────────────┘
                    │ API                                    
                    ▼
      ┌─────────────────────────────────────────────────────────┐
      │            Phoenix Security Cloud Connector            │
      │  • Pulls SCC assets & findings via Service Account     │
      └─────────────────────────────────────────────────────────┘
```

*Detectors generate **findings** which SCC aggregates. Phoenix fetches these findings via the Service Account you supply.*

---

## Detectors Supported

| Detector | Brief Description |
|----------|-------------------|
| Security Health Analytics | Misconfiguration & compliance checks across core services |
| Web Security Scanner | Crawls public App Engine / Cloud Run / GKE services for OWASP Top 10 issues |
| Event Threat Detection | Real-time log-based threat detection (IAM abuse, malware, etc.) |
| Container Threat Detection | Scans GKE container runtime for suspicious activity |
| Virtual Machine Threat Detection | Agentless memory-scan for suspicious patterns on Compute Engine VMs |
| Cloud Run Threat Detection *(Preview)* | Runtime threat detection for Cloud Run instances |
| Vulnerability Assessment | OS package & image CVE scanning for Compute & GKE |

> Not all detectors are Generally Available (GA) in every region. The script attempts GA first then falls back to *alpha* commands.

---

## Setup Options

### 1. Shell Script (Fast & Interactive)

See [gcp/enable_security_center.sh](enable_security_center.sh) – the script:

1. Lists projects you can access.
2. Lets you enable SCC + chosen detectors for all / selected projects.
3. Enables required APIs (`securitycenter.googleapis.com`, `websecurityscanner.googleapis.com`, …).

```bash
cd gcp
./enable_security_center.sh            # follow the prompts
```

### 2. Terraform (Automated / CI-friendly)

`gcp_security_center_setup.tf` enables SCC & Web Security Scanner APIs across projects defined in `project_ids` variable.

```bash
terraform init
terraform apply -var='project_ids=["my-dev","my-prod"]'
```

Terraform **does not** yet expose resources to toggle individual detectors. Use the script / CLI afterwards if detectors other than SHA are required.

---

## Asset Enumeration & Summary

Need a quick CSV with the **count of every asset type per project**? Use `gcp/list_assets.sh`.

### What it Does

* Iterates over **all projects** returned by `gcloud projects list`.
* Silently enables the **Cloud Asset API** (`cloudasset.googleapis.com`) on any project where it’s disabled (avoids the interactive *“Would you like to enable…?”* prompt).
* Queries `assetType` across the entire project via **Cloud Asset Inventory**.
* Appends one CSV row per asset type and a **TOTAL** row:

  `ProjectId,AssetType,Count`

### Usage

```bash
cd gcp
chmod +x list_assets.sh          # once

# Default output file → GcpAssetSummary-YYYYMMDDHHMMSS.csv
./list_assets.sh

# Custom path / filename
./list_assets.sh myAssets.csv

# Stream progress only (CSV goes to file, messages to stderr)
./list_assets.sh 2> /dev/stdout | tee run.log
```

Sample CSV (truncated):

```csv
ProjectId,AssetType,Count
dev-sandbox,google.compute.Instance,42
dev-sandbox,google.pubsub.Topic,5
dev-sandbox,TOTAL,52
prod-main,google.compute.Instance,87
prod-main,google.sql.Instance,3
prod-main,TOTAL,90
```

The resulting file shares the **same column layout** as the Azure summaries, making cross-cloud comparisons a breeze.

---

## Service Account & Credentials

To let Phoenix read SCC findings you need a Service Account with read-only roles and a JSON key:

1. **Create Service Account** (console or CLI):
   ```bash
   gcloud iam service-accounts create phoenix-scc-reader \
     --description="Read-only SCC for Phoenix" \
     --display-name="Phoenix SCC Reader"
   ```
2. **Grant Roles** *(org-level recommended)*:
   ```bash
   ORG_ID=$(gcloud organizations list --format="value(ID)" | head -1)
   SA="phoenix-scc-reader@$(gcloud config get-value project).iam.gserviceaccount.com"
   gcloud organizations add-iam-policy-binding $ORG_ID \
     --member="serviceAccount:$SA" \
     --role="roles/cloudasset.viewer"
   gcloud organizations add-iam-policy-binding $ORG_ID \
     --member="serviceAccount:$SA" \
     --role="roles/securitycenter.findingsViewer"
   # (repeat for other roles listed earlier)
   ```
3. **Generate JSON Key** and download:
   ```bash
   gcloud iam service-accounts keys create phoenix-scc-reader.json \
     --iam-account=$SA
   # Store safely (e.g., password manager / secret store)
   ```

---

## Phoenix Platform Integration

In **Phoenix**: Integrations → Scanners → *GCP Security Center* → **Add Scanner**

Fill fields:

| Field | Value |
|-------|-------|
| Scanner Name | Any friendly label |
| Organisation ID | Output of `gcloud organizations list` |
| Service Account Key JSON | Upload the `.json` file you downloaded |
| Project Selection | *All* or pick subset |

Click **Create Scanner**. Phoenix will queue the first ingestion; subsequent syncs run periodically.

---

## Troubleshooting & FAQ

| Symptom | Resolution |
|---------|------------|
| `PERMISSION_DENIED` when enabling API | Ensure your identity has `roles/serviceusage.serviceUsageAdmin` on the project. |
| Detector enable fails in script | The detector may still be **Preview** in your project/region. Try `gcloud alpha scc settings services list` to verify availability. |
| Phoenix shows `0 assets` | Confirm SCC has at least one detector enabled and findings exist. Use `gcloud scc findings list --organization=$ORG_ID --limit=5`. |
| Exceeded Asset quota | SHA & Vulnerability Assessment can generate many findings. Consider narrowing scope or upgrading SCC tier. |

---

## Cleanup

Disable APIs and optionally delete findings:

```bash
# disable APIs
gcloud services disable securitycenter.googleapis.com --project $PROJECT_ID --quiet
gcloud services disable websecurityscanner.googleapis.com --project $PROJECT_ID --quiet
# delete service account
gcloud iam service-accounts delete phoenix-scc-reader@${PROJECT_ID}.iam.gserviceaccount.com --quiet
```

Terraform users can simply run `terraform destroy` if they only need to disable APIs.

---

## Costs & Quotas

* **SCC Standard tier** is free; **SCC Premium** (needed for certain detectors) bills per asset & finding.
* Some detectors (ETD, VMTD) ingest logs or perform scans that may incur additional charges.
* Web Security Scanner launches crawlers that **generate external traffic**—budget accordingly.

Set up **Budgets & Alerts** in Cloud Billing and regularly review SCC usage reports.

---

## References

* [Security Command Center Overview](https://cloud.google.com/security-command-center/docs/overview)
* [Managing Detector Settings](https://cloud.google.com/security-command-center/docs/how-to-manage-detector-settings)
* [Pricing](https://cloud.google.com/security-command-center/pricing)
* [Phoenix Security Docs](https://docs.phoenix.security)

---

## License

MIT — see repository root `LICENSE`. 