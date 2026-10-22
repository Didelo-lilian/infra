variable "github_owner" {
  description = "GitHub organization whose repositories, secrets and labels are managed here."
  type        = string
  default     = "Didelo-lilian"
}

variable "domain" {
  description = "DNS zone managed here, hosted by OVHcloud."
  type        = string
  default     = "didelo.fr"
}

variable "server_ipv4" {
  description = "Public IPv4 of the VPS."
  type        = string
  default     = "51.254.223.51"
}

variable "server_ipv6" {
  description = "Public IPv6 of the VPS."
  type        = string
  default     = "2001:41d0:305:2100::1:5594"
}
