+++
title = "Securing my homelab"
date = "2024-10-25T04:35:53Z"
author = "ImDevinC"
authorTwitter = "ImDevinC" #do not include @
cover = ""
tags = ["kubernetes", "homelab", "security", "nginx", "authentik"]
keywords = ["", ""]
description = "Adding some basic security to my homelab"
showFullContent = false
readingTime = true
hideComments = false
color = "" #color from the theme settings
type = "post"
+++
# Introduction
Awhile ago I setup my homelab running on a kubernetes server sitting in my office. You can read about it in my other blog post here: [Migrating my homelab](https://imdevinc.com/posts/homelab). One thing that security focused people will probably immediately notice, is that I have public facing services but no mention of a firewall or security product. Luckily, I have yet to have anything negative happen, but that doesn't mean people haven't tried. If I occasionally look at my access logs, I can see quite a few random IP's hitting my endpoints looking for something.
I stumbled upon a reddit post in [/r/homelab](https://reddit.com/r/homelab) where someone was using [Crowdsec](https://crowdsec.net), and that's what prompted me to start digging in.

> To get a better idea of my homelab, here's a simple diagram showing what it looks like before I get started with the work below. It's not complete, but it will hopefully give a good idea of what I'm working with
![Starting setup](/images/homelab-secure-1.png)

# Starting simple, Crowdsec
I mentioned above that I didn't have _any_ security but that's partly a lie. On my raspberry pi, I am running [fail2ban](https://github.com/fail2ban/fail2ban) which allows you to define some basic rules (or use pre-provided ones) to block traffic. Nothing had been blocked on my pi-hole, but that's really to be expected since only wireguard is exposed there and the rest of the services go directly to my homelab.
Since Crowdsec is what started my initiative, I figured I would start there. Luckily, setting up Crowdsec is _extremely_ simple if you're using kubernetes. I installed the [helm chart](https://github.com/crowdsecurity/helm-charts/tree/main/charts/crowdsec) and made sure to tell it that I'm using nginx-ingress in the `values.yaml` and pointed it to my logs. At that point, I started getting some more advanced protection based on the Crowdsec rules that they have configured which are much more robust. I validated the block was working by doing some nefarious actions against my network, and verified I was getting denied. Secured!
![Crowdsec](/images/homelab-secure-2.png)

# But what if we want to be MORE secure?
I felt pretty good about having Crowdsec configured, but as I thought about it more, I realized that I am potentially still open to some other forms of issues like DDOS if someone gets my IP address. To be fair, even with this solution I'm about to discuss that can still be possible, but I wanted to reduce the possibility of someone getting my IP address easily. 
Since I was already using Cloudflare, I decided it would be a good idea to look at [Cloudflare Tunnel](https://www.cloudflare.com/products/tunnel/), which allows you to setup an internal tunnel that Cloudflare routes traffic over, effectively hiding your public IP address. I realize this isn't flawless, but it was better than nothing.

Setting up the tunnel is fairly easy. I used a terraform block to create a new DNS tunnel in Cloudflare for each domain I wanted:
```hcl
locals {
  tunneled_domains = toset([
    "gha-dashboard",
    "homeassistant",
    "obsidian-livesync",
    "remote",
    "wallabag"
  ])
}

...

resource "cloudflare_record" "tunnel" {
  for_each = local.tunneled_domains
  zone_id  = cloudflare_zone.main.id
  name     = each.value
  value    = local.tunnel_domain
  proxied  = true
  type     = "CNAME"
  comment  = "managed by terraform"
}
```

This creates the DNS entries that are needed in my Cloudflare account, but then I needed to create the other end of the tunnel inside of my own network. Cloudflare provides a sample [deployment.yaml](https://github.com/cloudflare/argo-tunnel-examples/blob/master/named-tunnel-k8s/cloudflared.yaml) file to configure this. I made some changes near the bottom of this file to match my external hostname (IE: `wallabag.mydomain.com`) to the **internal service name** of the service (`http://wallabag.wallabag:80`). I also needed to create the Cloudflare tunnel credentials, the instructions for which can be found [here](https://github.com/cloudflare/argo-tunnel-examples/blob/master/named-tunnel-k8s/README.md). Add this secret to your deployment and make sure to update the reference in the `volumeMount`.
Once deployed, give your DNS a few minutes to propagate and let the pods come up, and you should be able to access your services using the DNS name, but now routed through Cloudflare to hide your IP address. You can validate by using `dig <hostname>`.

Here's where we are now!
![Cloudflare Tunnel](/images/homelab-secure-3.png)

# Caveat
You may notice something in that screenshot above. My external services are no longer protected by Crowdsec. I know this is a gap at the moment, that I plan on addressing in the future, but at this point I'm ok with the trade-off.

Let me know if have you any feedback on ways to improve my security, or any questions!
