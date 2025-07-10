#!/usr/bin/env bash
# list_assets.sh
# -----------------------------------------------------------------------------
# Enumerates all resources across accessible Google Cloud projects via
# Cloud Asset Inventory and outputs their full resource names.
# -----------------------------------------------------------------------------
# REQUIREMENTS
#   * gcloud CLI with `cloudasset` and `projects` APIs enabled
#   * IAM roles (minimum):
#       - roles/cloudasset.viewer on each project
#       - roles/resourcemanager.projectViewer to list projects
# -----------------------------------------------------------------------------
set -euo pipefail

OUT_FILE=${1:-}

command -v gcloud >/dev/null 2>&1 || { echo "gcloud not installed: https://cloud.google.com/sdk/docs/install" >&2; exit 1; }

ACTIVE=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" || true)
if [[ -z "$ACTIVE" ]]; then
  echo "No active gcloud account. Run 'gcloud auth login' first." >&2
  exit 1
fi

PROJECTS=$(gcloud projects list --format="value(projectId)" || true)
if [[ -z "$PROJECTS" ]]; then
  echo "No projects visible to this account." >&2
  exit 1
fi

if [[ -n "$OUT_FILE" ]]; then : > "$OUT_FILE"; fi

echo "Enumerating assets… this may take a while."

for prj in $PROJECTS; do
  echo "# --- $prj ---" | { [[ -n "$OUT_FILE" ]] && tee -a "$OUT_FILE" || cat; }
  gcloud asset search-all-resources --project="$prj" --format="value(name)" |
    { [[ -n "$OUT_FILE" ]] && tee -a "$OUT_FILE" || cat; }
  echo "" | { [[ -n "$OUT_FILE" ]] && tee -a "$OUT_FILE" || true; }
done

echo "Done. Asset list complete." 