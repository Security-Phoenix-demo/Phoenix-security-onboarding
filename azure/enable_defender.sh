#!/usr/bin/env bash
# enable_defender.sh
# ----------------------------------------------------------------------------
# Interactive helper to enable Microsoft Defender for Cloud (Standard tier)
# and Microsoft Defender for Endpoint integration across multiple Azure
# subscriptions.
#
# Requirements:
#   * Azure CLI (az) ≥ 2.45
#   * Logged-in user/service principal with at least
#       - Security Admin or Owner on target subscriptions
#       - Microsoft Defender for Cloud registration feature enabled (default)
# ----------------------------------------------------------------------------
set -euo pipefail

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m"

command -v az >/dev/null 2>&1 || { echo -e "${RED}✘ Azure CLI (az) not found. Install from https://aka.ms/InstallAzureCLI${NC}"; exit 1; }

# Check login
if ! az account show &>/dev/null; then
  echo -e "${YELLOW}You are not logged in. Opening browser...${NC}"
  az login --use-device-code || { echo -e "${RED}Failed to login.${NC}"; exit 1; }
fi

echo -e "${GREEN}✔ Logged in as $(az account show --query user.name -o tsv)${NC}"

# List subscriptions the identity can access
SUBS=$(az account list --query "[].{name:name,id:id}" -o tsv)
if [[ -z "$SUBS" ]]; then
  echo -e "${RED}No subscriptions found for this account.${NC}" && exit 1
fi

echo -e "${GREEN}Subscriptions detected:${NC}"
while IFS=$'\t' read -r sub_name sub_id; do
  printf "  - %s (%s)\n" "$sub_name" "$sub_id"
done <<< "$SUBS"

echo -ne "\nEnable Defender on ${YELLOW}ALL${NC} subscriptions? (y/N): "
read -r all_subs
if [[ "$all_subs" =~ ^[Yy]$ ]]; then
  SELECTED_SUBS=$(echo "$SUBS" | cut -f2)
else
  echo -ne "Enter comma-separated subscription IDs: "
  read -r subs_input
  IFS=',' read -ra tmp <<< "$subs_input"
  SELECTED_SUBS=${tmp[@]}
fi

if [[ -z "$SELECTED_SUBS" ]]; then
  echo -e "${RED}No subscriptions selected – exiting.${NC}"; exit 1
fi

# Defender plans we want to enable (Standard tier)
DEFENDER_PLANS=(
  VirtualMachines        # Includes Defender for Servers / Endpoint integration
  AppServices
  SqlServers
  SqlServerVirtualMachines
  StorageAccounts
  KubernetesService
  ContainerRegistry
  KeyVaults
)

for SUB_ID in $SELECTED_SUBS; do
  echo -e "\n${YELLOW}▶ Processing subscription: $SUB_ID${NC}"
  az account set --subscription "$SUB_ID"

  # Enable each Defender plan to Standard tier
  for plan in "${DEFENDER_PLANS[@]}"; do
    echo -e "  • Enabling Standard tier for $plan"
    az security pricing create --name "$plan" --tier Standard --auto-enable true --verbose || true
  done

  # Enable integration with Microsoft Defender for Endpoint (if not default)
  echo -e "  • Ensuring Defender for Endpoint integration (WDATP setting) is On"
  az security setting update --name WDATP --setting-value On --verbose || true

  echo -e "${GREEN}✔ Completed subscription: $SUB_ID${NC}"
done

echo -e "\n${GREEN}🎉  Done! Microsoft Defender for Cloud Standard enabled across selected subscriptions.${NC}" 