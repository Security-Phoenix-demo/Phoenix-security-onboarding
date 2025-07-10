terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
  }
}

###############################################################################
# INPUT VARIABLES                                                             #
###############################################################################

variable "project_ids" {
  description = "List of project IDs on which to enable Security Command Center."
  type        = list(string)
}

variable "region" {
  description = "Default region (not strictly required for SCC but useful for provider)."
  type        = string
  default     = "us-central1"
}

###############################################################################
# PROVIDER                                                                    #
###############################################################################

# The google provider needs a single project set. We arbitrarily pick the
# first entry; individual resources override it via the `project` argument.
provider "google" {
  project = element(var.project_ids, 0)
  region  = var.region
}

###############################################################################
# ENABLE APIS                                                                  #
###############################################################################

# Enable SCC API for each target project
resource "google_project_service" "security_center_api" {
  for_each           = toset(var.project_ids)
  project            = each.value
  service            = "securitycenter.googleapis.com"
  disable_on_destroy = false
}

# Optionally enable Web Security Scanner because its detector relies on it.
resource "google_project_service" "web_security_scanner_api" {
  for_each           = toset(var.project_ids)
  project            = each.value
  service            = "websecurityscanner.googleapis.com"
  disable_on_destroy = false
}

###############################################################################
# OUTPUTS                                                                     #
###############################################################################

output "enabled_projects" {
  description = "Projects where Security Command Center API is now enabled."
  value       = [for p in google_project_service.security_center_api : p.project]
} 