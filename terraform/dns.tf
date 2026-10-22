# The whole zone except NS/SOA lives here: a record added in the OVH console would be invisible to Terraform.
locals {
  dns_records = {
    # Apex and every subdomain reach the VPS, where Traefik routes by host name.
    apex_a        = { subdomain = "", type = "A", target = var.server_ipv4 }
    apex_aaaa     = { subdomain = "", type = "AAAA", target = var.server_ipv6 }
    wildcard_a    = { subdomain = "*", type = "A", target = var.server_ipv4 }
    wildcard_aaaa = { subdomain = "*", type = "AAAA", target = var.server_ipv6 }

    # No mail is sent or received on this domain: say so, so nobody can send mail in its name.
    null_mx = { subdomain = "", type = "MX", target = "0 ." }
    spf     = { subdomain = "", type = "TXT", target = "\"v=spf1 -all\"" }
    dmarc   = { subdomain = "_dmarc", type = "TXT", target = "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s\"" }
    dkim    = { subdomain = "*._domainkey", type = "TXT", target = "\"v=DKIM1; p=\"" }

    # Only Let's Encrypt may issue certificates for the domain, wildcard included.
    caa_issue     = { subdomain = "", type = "CAA", target = "0 issue \"letsencrypt.org\"" }
    caa_issuewild = { subdomain = "", type = "CAA", target = "0 issuewild \"letsencrypt.org\"" }
  }
}

resource "ovh_domain_zone_record" "this" {
  for_each = local.dns_records

  zone      = var.domain
  subdomain = each.value.subdomain
  fieldtype = each.value.type
  target    = each.value.target
  ttl       = 3600
}
