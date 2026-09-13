---
aliases: [APT cache, apt-cacher-ng]
tags: [guide, network]
type: guide
---

# APT cache (10.8.0.8:3142)

[[40-Guides/Guides-MOC|← Guides]] · [[10-Hosts/MicroVMs|MicroVMs]] · Source `docs/apt-cache.md`. The `aptcache` VM runs on [[10-Hosts/mireo|mireo]].

## One-liner

```bash
echo 'Acquire::http::Proxy "http://10.8.0.8:3142";' | sudo tee /etc/apt/apt.conf.d/00proxy
sudo apt update
```

## Per repo (exempt local mirrors)

```
Acquire::http::Proxy::deb.debian.org "http://10.8.0.8:3142";
Acquire::http::Proxy::archive.ubuntu.com "http://10.8.0.8:3142";
Acquire::http::Proxy::security.ubuntu.com "DIRECT";
```

## Verify / remove

```bash
curl -I http://10.8.0.8:3142/acng-report.html
# cache hits: /var/log/apt-cacher-ng/ on mireo
sudo rm /etc/apt/apt.conf.d/00proxy
```

Only reachable inside LAN 10.8.0.0/24.
