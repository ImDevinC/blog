locals {
  cloudflare_account_id = "160dde3020d94b782e2085939a53c2d6"
  name                  = "blog"
  hostname              = "${local.name}.imdevinc.com"
}

resource "cloudflare_pages_project" "main" {
  account_id        = local.cloudflare_account_id
  name              = local.name
  production_branch = "main"

  build_config {
    build_caching   = false
    build_command   = "hugo --minify"
    destination_dir = "public"
  }

  source {
    type = "github"
    config {
      pr_comments_enabled = false
      owner               = "ImDevinC"
      production_branch   = "main"
      repo_name           = "blog"
    }
  }
}

resource "cloudflare_pages_domain" "main" {
  account_id   = local.cloudflare_account_id
  project_name = cloudflare_pages_project.main.name
  domain       = local.hostname
}

resource "cloudflare_record" "main" {
  zone_id = data.terraform_remote_state.site.outputs.cloudflare_zone_id
  name    = local.name
  value   = cloudflare_pages_project.main.subdomain
  proxied = true
  type    = "CNAME"
}
