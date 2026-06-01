# APT Cache Proxy (mireo 10.8.0.8:3142)

## One-liner

```bash
echo 'Acquire::http::Proxy "http://10.8.0.8:3142";' | sudo tee /etc/apt/apt.conf.d/00proxy
```

## Per-machine

`/etc/apt/apt.conf.d/00proxy`:

```
Acquire::http::Proxy "http://10.8.0.8:3142";
```

## Per-repo override (skip proxy for local mirrors)

```
Acquire::http::Proxy::deb.debian.org "http://10.8.0.8:3142";
Acquire::http::Proxy::archive.ubuntu.com "http://10.8.0.8:3142";
Acquire::http::Proxy::security.ubuntu.com "DIRECT";
```

## Verify

```bash
sudo apt update
# Check /var/log/apt-cacher-ng/ on mireo for hits
curl -I http://10.8.0.8:3142/acng-report.html
```

## Remove

```bash
sudo rm /etc/apt/apt.conf.d/00proxy
```
