#!/usr/bin/env bash
# extract_resource_fields.sh
# -----------------------------------------------------------------------------
# Given a list of AWS ARNs (for example the output of list_assets-aws.sh), this
# script prints only the resource *type* and the resource *identifier* in two
# space-separated columns.
#
#   arn:aws:ec2:eu-west-2:123456789012:internet-gateway/igw-0c0414f67fea03311
#   └─────────────┬─────────────┘ └───────────────┬────────────────────────┘
#   resource type │           resource identifier (may contain ":" or "/")
#
# Example usage:
#   # Parse a file produced by the enumerator
#   ./extract_resource_fields.sh ~/Downloads/assets.txt
#
#   # Or pipe directly
#   ./list_assets-aws.sh | ./extract_resource_fields.sh
#
# The script ignores any lines that do not start with the literal "arn:".
# -----------------------------------------------------------------------------
set -euo pipefail

INPUT_FILE=${1:-/dev/stdin}

awk -F ':' '
  # Process only ARN lines
  /^arn:/ {
    # Reconstruct the resource part (everything after the account-id)
    resource = $6;
    for (i = 7; i <= NF; i++) {
      resource = resource ":" $i;
    }

    # Split resource on first "/" or ":" to obtain the type and identifier
    if (index(resource, "/") != 0) {
      split(resource, arr, "/");
    } else {
      split(resource, arr, ":");
    }

    rtype = arr[1];
    rid   = (length(arr) > 1) ? arr[2] : "";

    # Output: <resource_type> <resource_id>
    if (rid == "") {
      print rtype;
    } else {
      print rtype, rid;
    }
  }
' "${INPUT_FILE}" 