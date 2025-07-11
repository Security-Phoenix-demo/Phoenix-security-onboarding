#!/usr/bin/env bash
# summarize_gcp_asset_counts.sh (GCP)
# -----------------------------------------------------------------------------
# Enumerates *every* project visible to the current gcloud identity and
# produces a CSV with the count of each asset type plus a TOTAL row per project.
#
# Columns: ProjectId,AssetType,Count
#
# USAGE
#   ./list_assets.sh                         # CSV → GcpAssetSummary-YYYYMMDDHHMMSS.csv
#   ./list_assets.sh mySummary.csv           # custom output path
# -----------------------------------------------------------------------------
set -euo pipefail

OUT_FILE=${1:-GcpAssetSummary-$(date +%Y%m%d%H%M%S).csv}

echo "ProjectId,AssetType,Count" > "$OUT_FILE"

command -v gcloud >/dev/null || { echo "gcloud CLI not found. Install Google Cloud SDK." >&2; exit 1; }

PROJECTS=$(gcloud projects list --format="value(projectId)")

for prj in $PROJECTS; do
  echo "Processing $prj …" >&2

  # Ensure Cloud Asset API is enabled for the project (avoids interactive prompt)
  if ! gcloud services list --enabled --project "$prj" --format="value(config.name)" | grep -q "cloudasset.googleapis.com"; then
    echo "  Enabling Cloud Asset API on $prj (one-time)…" >&2
    # This command is non-interactive; it waits until the API is enabled
    gcloud services enable cloudasset.googleapis.com --project "$prj" >/dev/null
  fi

  # Query all asset types in the project (assetType field only)
  # Output lines like: google.compute.Instance
  mapfile -t lines < <(
    gcloud asset search-all-resources \
      --project "$prj" \
      --format="value(assetType)" || true
  )

  if [[ ${#lines[@]} -eq 0 ]]; then
    echo "  (no resources found)" >&2
    continue
  fi

  # Count occurrences of each assetType
  total=0
  printf '%s\n' "${lines[@]}" | sort | uniq -c | while read -r count type; do
    printf '%s,%s,%d\n' "$prj" "$type" "$count" >> "$OUT_FILE"
    total=$((total + count))
  done

  # Append TOTAL row for the project
  printf '%s,%s,%d\n' "$prj" "TOTAL" "$total" >> "$OUT_FILE"
  echo "  Total resources: $total" >&2
  echo "" >&2

done

echo "Summary written to $OUT_FILE" >&2 