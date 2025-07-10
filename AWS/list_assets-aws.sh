#!/usr/bin/env bash
# list_assets.sh
# -----------------------------------------------------------------------------
# Enumerates AWS resources across ALL regions using the Resource Groups
# Tagging API (`tag:GetResources`) and prints a list of ARNs to stdout.
# 
# OUTPUT: one ARN per line → <region>_assets.txt (or stdout if no file provided)
# -----------------------------------------------------------------------------
# REQUIREMENTS
#   * AWS CLI v2 configured (`aws configure` / assumed role)
#   * IAM permissions:
#       - tag:GetResources
#       - ec2:DescribeRegions (to list regions)
# NOTE: The Tagging API only returns **taggable** resources. Some non-taggable
#       services (e.g., IAM roles, Route53 hosted zones) are not included.
# -----------------------------------------------------------------------------
set -euo pipefail

OUT_FILE=${1:-}

if ! command -v aws &>/dev/null; then
  echo "AWS CLI not found. Install from https://docs.aws.amazon.com/cli/" >&2
  exit 1
fi

REGIONS=$(aws ec2 describe-regions --all-regions --query 'Regions[].RegionName' --output text)

collect() {
  local region=$1
  echo "# --- $region ---"
  aws resourcegroupstaggingapi get-resources \
    --region "$region" \
    --query 'ResourceTagMappingList[].ResourceARN' \
    --output text
}

if [[ -n "$OUT_FILE" ]]; then : > "$OUT_FILE"; fi

for r in $REGIONS; do
  if [[ -n "$OUT_FILE" ]]; then
    collect "$r" >> "$OUT_FILE"
  else
    collect "$r"
  fi
done

echo "Done. Asset list complete." 