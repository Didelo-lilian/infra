# Credentials come from the environment: OVH_APPLICATION_KEY, OVH_APPLICATION_SECRET,
# OVH_CONSUMER_KEY and GITHUB_TOKEN. They are never written in this repository.
provider "ovh" {
  endpoint = "ovh-eu"
}

provider "github" {
  owner = var.github_owner
}
