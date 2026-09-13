---
aliases: [Printing, CUPS, Printer]
tags: [guide, network]
type: guide
---

# Printing (CUPS VM 10.8.0.6)

[[40-Guides/Guides-MOC|← Guides]] · Source `docs/printing.md`.

Epson ET-2860 + Lexmark (driverless IPP), VM `cups` on 10.8.0.6:631, advertised via Avahi `_ipp._tcp`.

## NixOS (x270)

`profiles/base.nix` is enough — CUPS + Avahi discover the printer automatically. Just print.

## Other distros

```bash
# Ubuntu/Debian
sudo apt install cups printer-driver-escpr avahi-daemon
sudo systemctl enable --now cups
# Fedora
sudo dnf install cups epson-inkjet-printer-escpr avahi
# Arch
sudo pacman -S cups avahi nss-mdns
```

On Arch, add `mdns_minimal` to the `hosts:` line in `/etc/nsswitch.conf`.

## Manual setup (without Avahi)

```
ipp://10.8.0.6/printers/Epson-ET-2860  → ESC/P-R 2 driver
ipp://10.8.0.6/printers/Lexmark        → IPP Everywhere
```

```bash
lpadmin -p Epson-ET-2860 -E -v ipp://10.8.0.6/printers/Epson-ET-2860 \
  -m epson-inkjet-printer-escpr2/Epson-ET-2860_Series-epson-escpr2-en.ppd -o PageSize=A4
lpadmin -p Lexmark -E -v ipp://10.8.0.6/printers/Lexmark -m everywhere -o PageSize=A4
lpoptions -d Epson-ET-2860
echo test | lp -d Epson-ET-2860
lpstat -p Epson-ET-2860; lpinfo -m | grep -i ET-2860
```

## Debugging

```bash
ssh root@mireo systemctl status microvm@cups
ssh root@cups lpstat -t; ssh root@cups lpq
```

Only reachable inside LAN 10.8.0.0/24 (or via Tailscale).
