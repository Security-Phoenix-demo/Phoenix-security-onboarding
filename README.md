# Phoenix Security Cloud On-Boarding

Welcome! This repository contains all the Infrastructure-as-Code (IaC) templates and helper scripts you need to integrate **Phoenix Security** with your cloud environments. We currently support:

| Cloud Provider | Folder | What It Does |
|----------------|--------|--------------|
| **Amazon Web Services (AWS)** | [`AWS/`](AWS/) | Enables Security Hub, GuardDuty, and Inspector & creates a read-only IAM user for Phoenix Security. Supports CloudFormation **or** Terraform. |
| **Google Cloud Platform (GCP)** | [`gcp/`](gcp/) | Enables Security Command Center (SCC) + key detectors (Security Health Analytics, Web Security Scanner, etc.). Interactive Bash script **and** Terraform provided. |
| **Microsoft Azure** | [`azure/`](azure/) | Enables Microsoft Defender for Cloud (Standard) and integrates Defender for Endpoint across subscriptions via interactive Azure CLI script. |

---

## Choosing a Path

* **AWS users** → open [`AWS/README.md`](AWS/README.md) and follow the CloudFormation or Terraform quick-start.
* **GCP users** → open [`gcp/README.md`](gcp/README.md) and decide between the interactive script (`enable_security_center.sh`) or Terraform module.
* **Azure users** → open [`azure/README.md`](azure/README.md) and run the Azure CLI helper script.

Both cloud-specific guides include:
1. Architecture overview.
2. Prerequisites & required roles/permissions.
3. Step-by-step instructions.
4. Security considerations & cleanup steps.

---

## Repository Structure

```
├── AWS/                          # AWS onboarding toolkit
│   ├── README.md
│   ├── phoenix_security_hub_setup.yaml
│   └── aws_phoenix_security_integration.tf
│
├── gcp/                          # GCP onboarding toolkit
│   ├── README.md
│   ├── enable_security_center.sh
│   └── gcp_security_center_setup.tf
│
├── azure/                        # Azure onboarding toolkit
│   ├── README.md
│   └── enable_defender.sh
│
└── README.md                     # ← you are here
```

---

## Contributing

We welcome pull requests! If you have improvements for additional cloud providers or refinements to existing scripts, please open an issue first so we can coordinate.

---

## License

MIT — see `LICENSE` in the repository root. 