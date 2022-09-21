terraform {
  required_version = ">= 1.1.6"
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
provider "google-beta" {
  project = var.project_id
}
