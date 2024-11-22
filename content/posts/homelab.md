+++
title = "Migrating my homelab"
date = "2023-01-22T00:43:38Z"
author = "ImDevinC"
authorTwitter = "ImDevinC" #do not include @
cover = ""
tags = ["kubernetes", "homelab"]
keywords = ["kubernetes", "homelab", "nginx", "metallb", "argo"]
description = "Migrating my homelab from Proxmox to Kubernetes"
showFullContent = false
readingTime = true
hideComments = false
color = "" #color from the theme settings
type = "post"
+++
> Note, this will be a very high level overview of how I got my cluster and services running. If you would like more detail of how I did this, please let me know and I can break these down in a separate post in the future
# Introduction
A few years ago, I setup [Proxmox](https://www.proxmox.com/) on my homelab server to manage multiple VM's and configurations. Since then, I realized that I wasn't really using the VM's anymore other than running one VM that housed all my docker services and one containerized version of [HomeAssistant](https://www.home-assistant.io/). In my main VM that housed all my docker services, I ran [Portainer](https://www.portainer.io/) to help maintain my services and keep things a bit more organized. This worked wel labout 90% of the time, but I ran into a few issues that were annoying:
- Portainer doesn't have a concept of scheduled jobs. So if I just wanted to run a cron task, I had to manage it separately
- If a service failed to start, there wasn't an easy to get notified about it, so I'd just have to wait to find out that a service wasn't running
- Occasionally, if a service failed to start, Portainer would lose context to any volumes I had attached. This would cause me to lose all data for that service, which was very frustrating

The last bullet point was really the killer for me. I didn't use my server for anything life altering, but I ran a few different services that reconfiguring would be a pain. A full list of everything running was:
- **mediaservice**: A collection of services that managed my home media
    - [Plex](https://plex.tv)
    - [Sonarr](https://sonarr.tv/)
    - [Radarr](https://radarr.video/)
    - [Tautulli](https://tautulli.com/)
    - [nzbget](https://nzbget.net/)
    - [plex-meta-manager](https://github.com/meisnate12/Plex-Meta-Manager)
    - [requestrr](https://github.com/darkalfx/requestrr)
- **streamnotifier**: A service I built to post to Discord when I start streaming
- **mongodb**: The backend for stream-notifier, and a common database I use with other projects
- **[nginx-proxy-manager](https://nginxproxymanager.com/)**: A service that acted as a reverse proxy in front of everything else to route traffic based on host path, and also make sure I had certificates for external services that needed them

Because I didn't want my mediaservice to go down, I first spun up a new VM in my existing Proxmox cluster that I would use to bootstrap my cluster and getting a working version. I started with Arch Linux, simply because it's what I use as my main OS and am most familiar with it. I then followed [this guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/) and [this guide specific to Arch](https://wiki.archlinux.org/title/Kubernetes) to get the cluster bootstrapped and running.
> Side note, most people would recommend not managing a control-plane by yourself but instead using something like k3s instead. I wanted to learn about the control-plane though, so I installed it.

## Automated deployments
Now that the cluster was running, I needed a way to easily manage what was running on my cluster. I could always just `kubectl apply` to apply any manifests I had, but I also knew that I didn't want to do that and would rather use a full [GitOps](https://www.gitops.tech/) flow. I had read about [ArgoCD](https://argoproj.github.io/cd/) in the past, and realized it fit my use case very well. Luckily, ArgoCD provides a helm chart for installation to get the service up and running easily. I also found a [great article](https://kubito.dev/posts/automated-argocd-app-of-apps-installation/) that helped me understand some concepts of using ArgoCD and walked through how to let ArgoCD manage ArgoCD once it was installed.
![ArgoCD installed](/images/argo-install.png)

## Getting mediaserver up and running
For the mediaserver, I found a very helpful [helm chart](https://github.com/kubealex/k8s-mediaserver-helm/tree/master/k8s-mediaserver) that had almost everything I needed for my mediaservice already, so I used this to get things up and running. The only real change is that it replaced nzbget with [Sabnzbd](https://sabnzbd.org/) and also added [Prowlarr](https://github.com/Prowlarr/Prowlarr) for manging my indexers. The documentation for all of this was great and I had all the services, PersistentVolumeClaims and more running in almost no time. Using the ArgoCD configuration, I added the Helm chart as a new application, and the install through easily with only minor debugging needed to fit my setup.
![mediaserver installed](/images/mediaserver-install.png)

## Accessing the Services Externally
This section was all new to me. Running things in Portainer before meant if I wanted to access a service, I simply setup port-forwarding on the Docker container, and setup nginx-proxy-manager to forward traffic from `stream-notifier.imdevinc.com` to the correct container. Looking at my current stack, I realized I had three issues:
1. I needed to be able to access the services externally from the cluster. IE: Instead of having to do `kubectl port-forward svc/radarr 9191:9191` I wanted to just be able to open `http://10.122.54.12:9191` in any browser on my network and access the service.
2. I needed to have some type of reverse proxy setup, so instead of having to type `http://10.122.54.12:9191` to access Radarr, I could just open a browser to `http://media.collins.home/radarr` and access the service.
3. I needed certificates for external facing services (streamnotifier). Since this service received webhooks from Twitch and has a public endpoint, I wanted to make sure it was properly secured with SSL.

Seeing my challenges, I started at the top of the list and worked down. For allowing access to the cluster from external services, I needed a [LoadBalancer](https://kubernetes.io/docs/concepts/services-networking/) service. Normally if you're running in the cloud, this is something like an ELB on AWS. But since I'm running on bare metal, I needed to use the adequately named [metallb](https://metallb.universe.tf/). Metallb grabs an IP address out of a pool that you provide to allow access into the cluster. In this case, I gave metallb a `10.*` address to match what my home network was using, and made sure that my router statically assigned that in the future. This was a very easy solution to get external access working, and required very little troubleshooting. I added my configuration to ArgoCD, made sure it deployed, and then I could see services by access them through an IP!

## Setting up DNS services
To start, I needed to find a way to allow for hostnames + paths to be routed to specific services. Luckily, nginx helps here just as it did with nginx proxy manager. There's a service named [nginx-ingress](https://github.com/kubernetes/ingress-nginx) that does exactly what's needed. I installed the helm chart using ArgoCD, and then added the proper annotations to my services to allow them to generate a new ingress service.

At this point, I realized I actually had a fourth issue. While I could setup routing for a host of `media.collins.home`, I had no local routing to tell my computer that `media.collins.home` should point to the metallb IP address. This meant finding a way to update my pi-hole automatically with the proper DNS names. And of course, someone had already thought of this! [external-dns](https://github.com/kubernetes-sigs/external-dns/) is a service that is able to update many types of DNS providers, including a pi-hole, with the proper DNS configuration. Once this was setup, I could now access my services through a browser at `http://media.collins.home/{prowlarr,radarr,etc}`

## Generating SSL certificates
In my Proxmox stack, I was using nginx-proxy-manager for both reverse proxying, and for generating SSL certificates through lets-encrypt. In the kubernetes world, a service should ideally handle a single thing, so while nginx-ingress could handle my reverse proxy setup, it would no longer manage my certificates. But as I was not the only person who had something like this before, [cert-manager](https://cert-manager.io/) exists to make things easier! This service allows for some basic configuration, and will automatically request certificates from multiple providers, one of which is Letsencrypt! Adding the service to ArgoCD simply meant I had to add the right annotations to the services I wanted a certificate for, and streamnotifer now had a valid certificate!

## Finalizing the setup
At this point, I had my entire stack running in the Proxmox VM that I had setup. The next step was actually tearing everything down and actually running it on baremetal. I crossed my fingers and wiped the hard drive (my media all exists on a separate LVM cluster housed in a HDD bay). I then followed the same setup guides that I mentioned above to get Arch linux installed, and a kubernetes control plane running on the cluster. Once done, I reinstalled ArgoCD from scratch, and then pointed it at my homelab [GitHub repo](https://github.com/imdevinc/homelab). I waited a few minutes, and it automatically started syncing all the changes I had already merged. After a few more minutes, the entire cluster was up and running successfully with no other changes needed. Using the GitOps flow saved me so much time and I'm glad I chose that route to start.

> As mentioned at the beginning, this is a very high level overview of what I did to get things running. If I broke down every detail, this post would be _very_ long. That being said, I'm glad to expand upon any questions someone might have. Feel free to leave a comment and let me know if you have any questions. Also, be sure to check out both the [CNCF](https://communityinviter.com/apps/cloud-native/cncf) and [Kubernetes](https://communityinviter.com/apps/kubernetes/community) Slack communities for any support you may need. They're extremely helpful!
