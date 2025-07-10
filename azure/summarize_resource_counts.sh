#!/usr/bin/env bash
# summarize_resource_counts.sh (Azure)
# -----------------------------------------------------------------------------
# Summarises Azure resource inventory (from Resource Graph TSV or stdin).
# For each subscription it prints:
#   • TOTAL number of resources
#   • Per-resource-type counts (descending)
# And writes the same information to a CSV identical to the PowerShell version
# (columns: SubscriptionName, SubscriptionId, ResourceType, Count).
#
# USAGE
#   ./summarize_resource_counts.sh <tsv_file> [output.csv]
#   cat azure_assets.tsv | ./summarize_resource_counts.sh -  summary.csv
# If no output CSV provided, a timestamped file is created.
# -----------------------------------------------------------------------------
set -euo pipefail

INPUT_FILE=${1:-/dev/stdin}
OUTPUT_CSV=${2:-AzureResourceSummary-$(date +%Y%m%d%H%M%S).csv}

# Associative arrays require Bash 4+
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "This script requires Bash 4+ (associative arrays)." >&2
  exit 1
fi

# Declare associative arrays for totals and per-type counts
declare -A TOTAL
declare -A TYPECOUNT

current_sub=""
current_name=""
sub_count=0
unique_subs=()

# Read line-by-line
while IFS= read -r line || [[ -n "$line" ]]; do
  # Detect subscription header lines: "# --- <subId> (<subName>) ---" OR "# --- <subId> ---"
  if [[ $line =~ ^#\ ---\ ([^[:space:]]+) ]]; then
    current_sub="${BASH_REMATCH[1]}"
    # Capture optional name in parentheses if present
    if [[ $line =~ \(([^)]+)\) ]]; then
      current_name="${BASH_REMATCH[1]}"
    else
      current_name="$current_sub"
    fi
    # Track order for progress display later
    unique_subs+=("$current_sub::$current_name")
    continue
  fi

  # Skip empties / comments
  [[ -z "$line" || $line =~ ^# ]] && continue

  # Split TSV → id, name, type, location (at minimum)
  IFS=$'\t' read -r id name rtype location _ <<< "$line"

  [[ -z "${rtype-}" || -z "$current_sub" ]] && continue

  TOTAL[$current_sub]=$(( ${TOTAL[$current_sub]:-0} + 1 ))
  TYPECOUNT["$current_sub|$rtype"]=$(( ${TYPECOUNT["$current_sub|$rtype"]:-0} + 1 ))
  sub_count=$((sub_count + 1))

done < "$INPUT_FILE"

echo "Processed $sub_count resource rows. Writing summary…" >&2

# Prepare CSV header
printf 'SubscriptionName,SubscriptionId,ResourceType,Count\n' > "$OUTPUT_CSV"

for entry in "${unique_subs[@]}"; do
  IFS='::' read -r subId subName <<< "$entry"
  echo "Subscription: $subName ($subId)"
  echo "Total resources: ${TOTAL[$subId]}"

  # TOTAL row
  printf '%s,%s,%s,%d\n' "$subName" "$subId" "TOTAL" "${TOTAL[$subId]}" >> "$OUTPUT_CSV"

  # Per-type rows, sorted desc
  while IFS=$' ' read -r type cnt; do
    printf "  %-50s %d\n" "$type" "$cnt"
    printf '%s,%s,%s,%d\n' "$subName" "$subId" "$type" "$cnt" >> "$OUTPUT_CSV"
  done < <(
    for key in "${!TYPECOUNT[@]}"; do
      if [[ $key == $subId\|* ]]; then
        echo "${key#*|} ${TYPECOUNT[$key]}"
      fi
    done | sort -k2 -nr
  )
  echo "" # Blank line

done

echo "Summary CSV written to $OUTPUT_CSV" >&2 