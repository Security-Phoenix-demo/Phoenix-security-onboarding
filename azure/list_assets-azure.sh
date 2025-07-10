#!/usr/bin/env bash
# list_assets.sh
# -----------------------------------------------------------------------------
# Enumerates all Azure resources across selected subscriptions using Azure
# Resource Graph and prints their IDs to stdout.
# -----------------------------------------------------------------------------
# REQUIREMENTS
#   * Azure CLI (`az`) ≥ 2.45 with Resource Graph extension (auto-installed)
#   * Azure role assignments:
#       - Reader or higher at subscription scope (provides Microsoft.Resources/read)
#       - Microsoft.ResourceGraph/* (included with Reader)
# -----------------------------------------------------------------------------
set -euo pipefail

OUT_FILE=${1:-}

command -v az >/dev/null 2>&1 || { echo "Azure CLI not installed: https://aka.ms/InstallAzureCLI" >&2; exit 1; }

if ! az account show &>/dev/null; then
  echo "You are not logged in. Running az login..." >&2
  az login --use-device-code || { echo "Login failed." >&2; exit 1; }
fi

SUBS=$(az account list --query "[].id" -o tsv)
if [[ -z "$SUBS" ]]; then
  echo "No subscriptions accessible." >&2
  exit 1
fi

echo "Subscriptions: $SUBS"

QUERY="Resources | project id, name, type, location | order by type asc"

if [[ -n "$OUT_FILE" ]]; then : > "$OUT_FILE"; fi

for sub in $SUBS; do
  echo "# --- $sub ---" | { [[ -n "$OUT_FILE" ]] && tee -a "$OUT_FILE" || cat; }
  az graph query -q "$QUERY" --subscriptions "$sub" --first 1000 -o tsv |
    { [[ -n "$OUT_FILE" ]] && tee -a "$OUT_FILE" || cat; }
  echo "" | { [[ -n "$OUT_FILE" ]] && tee -a "$OUT_FILE" || true; }
done

echo "Done. Asset list complete." 