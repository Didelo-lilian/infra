terraform {
  required_version = ">= 1.14"

  # State lives in HCP Terraform with local execution: plans run on my machine or in CI,
  # credentials never leave them. Organization and workspace come from
  # TF_CLOUD_ORGANIZATION and TF_WORKSPACE.
  cloud {}

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 2.23"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }
}
