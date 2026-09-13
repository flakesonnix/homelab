---
aliases: [NFS client, NFS Ubuntu]
tags: [guide, network]
type: guide
---

# NFS client (mireo /data)

[[40-Guides/Guides-MOC|← Guides]] · [[10-Hosts/Network|Network]] · Source `docs/nfs-ubuntu-client.md`. Export `10.8.0.1:/data` → `10.8.0.0/24`, announced via Avahi `_nfs._tcp`.

## Quick test

```bash
sudo apt install -y nfs-common
sudo mkdir -p /mnt/mireo/data
showmount -e 10.8.0.1
sudo mount -t nfs4 -o soft,timeo=50,retrans=2 10.8.0.1:/data /mnt/mireo/data
touch /mnt/mireo/data/test-$(hostname).txt
```

## Permanent (fstab)

```
10.8.0.1:/data  /mnt/mireo/data  nfs4  soft,timeo=50,retrans=2,_netdev,nofail  0  0
```

```bash
sudo mount -a
ln -s /mnt/mireo/data ~/data
```

`soft`+`timeo`+`_netdev`+`nofail` = no boot hang when mireo is offline.

## On-demand (systemd.automount, recommended for laptops)

`mnt-mireo-data.mount` (Requires network-online, What 10.8.0.1:/data, Where /mnt/mireo/data, Type nfs4) + `mnt-mireo-data.automount` (same Where, TimeoutIdleSec 300):

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now mnt-mireo-data.automount
ls /mnt/mireo/data
```

## Permissions

The server maps everything via all_squash → UID 1000 / GID 100. `id -u` should print 1000, otherwise use the GUI (Nautilus/Dolphin `nfs://10.8.0.1/data`).

## Debugging

```bash
ping -c 3 10.8.0.1
nc -zv 10.8.0.1 2049
sudo umount -l /mnt/mireo/data   # when busy
```

GNOME: Files → Other Locations → `nfs://10.8.0.1/data`. KDE: Dolphin → Network → Shared Folders (NFS, via Avahi).
