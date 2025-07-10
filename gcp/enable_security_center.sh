#!/usr/bin/env bash
# enable_security_center.sh
# -----------------------------------------------------------------------------
# Interactive helper to enable Google Cloud Security Command Center (SCC) and
# its key detectors across one or more projects.
# -----------------------------------------------------------------------------
# Detectors covered:
#   - Security Health Analytics
#   - Web Security Scanner
#   - Event Threat Detection
#   - Container Threat Detection
#   - Virtual Machine Threat Detection
#   - Cloud Run Threat Detection (preview)
#   - Vulnerability Assessment
#
# Requirements:
#   * Google Cloud SDK (gcloud) ≥ 420.0.0 with Security Command Center commands
#   * jq (for JSON parsing)
#
# Usage:
#   ./enable_security_center.sh
# -----------------------------------------------------------------------------
set -euo pipefail

# Colour helpers
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m"

check_dependency() {
  command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}✘ $1 is required but not installed.${NC}"; exit 1; }
}

check_dependency gcloud
check_dependency jq

echo -e "${GREEN}✔ Dependencies verified${NC}"

echo -e "${YELLOW}Checking active gcloud account...${NC}"
ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" || true)
if [[ -z "${ACTIVE_ACCOUNT}" ]]; then
  echo -e "${RED}No active account found. Run 'gcloud auth login' or 'gcloud auth activate-service-account' first.${NC}"
  exit 1
fi

echo -e "Active account: ${GREEN}${ACTIVE_ACCOUNT}${NC}"

PROJECTS=$(gcloud projects list --format="value(projectId)" || true)
if [[ -z "$PROJECTS" ]]; then
  echo -e "${RED}No projects visible to this account. Ensure you have the 'viewer' role at minimum.${NC}"
  exit 1
fi

echo -e "\n${GREEN}Projects accessible:${NC}"
for p in $PROJECTS; do echo "  - $p"; done

echo -ne "\nDo you want to enable SCC and detectors on ${YELLOW}ALL${NC} projects above? (y/N): "
read -r enable_all
if [[ "$enable_all" =~ ^[Yy]$ ]]; then
  SELECTED_PROJECTS=($PROJECTS)
else
  echo -ne "Enter a comma-separated list of project IDs to target: "
  read -r project_input
  IFS=',' read -ra SELECTED_PROJECTS <<< "$project_input"
fi

if [[ ${#SELECTED_PROJECTS[@]} -eq 0 ]]; then
  echo -e "${RED}No projects selected. Exiting.${NC}"
  exit 1
fi

declare -A DETECTOR_MAP=(
  [1]="security-health-analytics"
  [2]="web-security-scanner"
  [3]="event-threat-detection"
  [4]="container-threat-detection"
  [5]="virtual-machine-threat-detection"
  [6]="cloud-run-threat-detection"
  [7]="vulnerability-assessment"
)

echo -e "\n${GREEN}Detector catalogue:${NC}"
for idx in "${!DETECTOR_MAP[@]}"; do
  det_name=${DETECTOR_MAP[$idx]}
  printf "  %s) %s\n" "$idx" "${det_name//-/ }"
done
printf "  a) All (default)\n"

echo -ne "Select detectors to enable (e.g., 1,3,5 or 'a' for all): "
read -r detector_choice

declare -a SELECTED_DETECTORS
if [[ -z "$detector_choice" || "$detector_choice" == "a" || "$detector_choice" == "A" ]]; then
  SELECTED_DETECTORS=("${DETECTOR_MAP[@]}")
else
  IFS=',' read -ra choices <<< "$detector_choice"
  for num in "${choices[@]}"; do
    num_trim=${num// /}
    if [[ -n "${DETECTOR_MAP[$num_trim]:-}" ]]; then
      SELECTED_DETECTORS+=("${DETECTOR_MAP[$num_trim]}")
    fi
  done
fi

if [[ ${#SELECTED_DETECTORS[@]} -eq 0 ]]; then
  echo -e "${RED}No detectors selected. Exiting.${NC}"
  exit 1
fi

# Function to enable SCC API and detectors per project
enable_detectors() {
  local project=$1
  echo -e "\n${YELLOW}▶ Enabling Security Command Center API for project: $project${NC}"
  gcloud services enable securitycenter.googleapis.com --project="$project" --quiet

  # Some detectors require extra APIs
  if [[ " ${SELECTED_DETECTORS[*]} " == *"web-security-scanner"* ]]; then
    gcloud services enable websecurityscanner.googleapis.com --project="$project" --quiet
  fi

  echo -e "${GREEN}✔ API(s) enabled${NC}"

  for det in "${SELECTED_DETECTORS[@]}"; do
    echo -e "  → Enabling detector: $det"
    # The official command syntax (GA as of 2023-10) is:
    #   gcloud scc settings services enable DETECTOR --project=PROJECT_ID --quiet
    # For preview-only detectors, the command might be under the 'alpha' group.
    if ! gcloud scc settings services enable "$det" --project="$project" --quiet 2>/dev/null; then
      echo -e "    ${RED}Failed (or feature in Preview). Attempting alpha command...${NC}"
      gcloud alpha scc settings services enable "$det" --project="$project" --quiet || \
        echo -e "    ${RED}Still failed – detector may not yet be available in this project/region.${NC}"
    fi
  done
  echo -e "${GREEN}✔ Completed project: $project${NC}"
}

for proj in "${SELECTED_PROJECTS[@]}"; do
  enable_detectors "$proj"
done

echo -e "\n${GREEN}🎉  All done!${NC} Detectors enabled where possible." 