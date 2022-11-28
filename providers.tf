terraform {
  required_version = ">= 1.1.6, < 1.3.0"
  #required_version = ">= 1.3.2"
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
  experiments = [module_variable_optional_attrs]
}

provider "google" {
  project = var.project_id
}

/* Shouldn't need this
provider "google-beta" {
  project = var.project_id
} */

