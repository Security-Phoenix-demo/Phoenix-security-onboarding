#!/usr/bin/env bash
# cloudshell_list_assets.sh
# -----------------------------------------------------------------------------
# AWS CloudShell-friendly asset enumerator.
#   • Runs across **all** AWS regions by default – or only the regions you pass as arguments.
#   • Uses the Resource Groups Tagging API (GetResources) and handles pagination.
#   • Prints one ARN per line.
# -----------------------------------------------------------------------------
# IAM permissions required by the executing principal:
#   - "tag:GetResources" on the account (allows listing taggable resources)
# -----------------------------------------------------------------------------
# Usage:
#   ./cloudshell_list_assets.sh                    # enumerate *all* regions
#   ./cloudshell_list_assets.sh us-east-1 eu-west-1  # enumerate only listed regions
#
# OPTIONAL ENV:
#   AWS_PROFILE / AWS_SESSION_TOKEN as usual.
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
set -euo pipefail

# Ensure tooling exists
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required (preinstalled in CloudShell)" >&2; exit 1; }
command -v jq  >/dev/null 2>&1 || { echo "jq is required; install with  \`sudo yum install -y jq\`" >&2; exit 1; }

# Determine regions
if [[ $# -gt 0 ]]; then
  REGIONS=("$@")
else
  REGIONS=($(aws ec2 describe-regions --query 'Regions[].RegionName' --output text))
fi

TOTAL=0

for REGION in "${REGIONS[@]}"; do
  echo "# --- $REGION ---"

  # Spinner in background to show progress per region
  spin() {
    local -a marks=("|" "/" "-" "\\")
    local i=0
    while :; do
      printf "\r%s Querying %s..." "${marks[$i]}" "$REGION"
      i=$(((i + 1) % 4))
      sleep 0.2
    done
  }
  spin &
  SPIN=$!

  TOKEN=""
  while :; do
    if [[ -z "$TOKEN" ]]; then
      RESP=$(aws resourcegroupstaggingapi get-resources --region "$REGION" --output json)
    else
      RESP=$(aws resourcegroupstaggingapi get-resources --region "$REGION" --output json --pagination-token "$TOKEN")
    fi

    COUNT=$(echo "$RESP" | jq '.ResourceTagMappingList | length')
    TOTAL=$((TOTAL + COUNT))
    echo "$RESP" | jq -r '.ResourceTagMappingList[].ResourceARN'

    TOKEN=$(echo "$RESP" | jq -r '.PaginationToken // ""')
    [[ "$TOKEN" == "null" || -z "$TOKEN" ]] && break
  done

  kill -9 $SPIN 2>/dev/null
  echo "Finished region $REGION (resources: $COUNT)" && echo
done

echo "Grand total resources across ${#REGIONS[@]} regions: $TOTAL" 