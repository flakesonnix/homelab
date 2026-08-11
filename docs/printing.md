# Printing

Network printers: **Epson ET-2860** and **Lexmark** (driverless IPP), hosted in the `cups` microVM on mireo at `10.8.0.6:631`.

The printers are shared via IPP and advertised via Avahi mDNS (`_ipp._tcp`), so they auto-discover on any LAN machine with Avahi support.

---

## NixOS (x270)

Printing is enabled by `profiles/base.nix`. CUPS auto-discovers the shared printer via Avahi. No extra config needed — open a print dialog and the printer appears.

---

## Non-NixOS distros

### Prerequisites

Install the Epson ESC/P-R 2 driver and CUPS:

| Distro | Command |
|--------|---------|
| Ubuntu / Debian | `sudo apt install cups printer-driver-escpr` |
| Fedora / RHEL | `sudo dnf install cups epson-inkjet-printer-escpr` |
| Arch | `sudo pacman -S cups` then AUR: `epson-inkjet-printer-escpr2` |
| openSUSE | `sudo zypper install cups epson-inkjet-printer-escpr` |

Start and enable CUPS:

```bash
sudo systemctl enable --now cups
```

---

### Auto-discovery (Avahi)

If your distro has Avahi running (`avahi-daemon`), the printer appears automatically in GNOME / KDE print dialogs. Nothing else needed.

Check Avahi is running:

```bash
systemctl status avahi-daemon
```

If not installed:

| Distro | Command |
|--------|---------|
| Ubuntu / Debian | `sudo apt install avahi-daemon` |
| Fedora / RHEL | `sudo dnf install avahi` |
| Arch | `sudo pacman -S avahi nss-mdns` |

On Arch, also enable mDNS in `/etc/nsswitch.conf` — change the `hosts:` line to include `mdns_minimal`:

```
hosts: mkcache files mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns
```

---

### Manual setup (if Avahi doesn't work)

Add the printer directly via CUPS web UI or `lpadmin`:

**Web UI:** open `http://localhost:631` → Administration → Add Printer → Internet Printing Protocol (IPP) → enter:

```
ipp://10.8.0.6/printers/Epson-ET-2860
```

Select driver: **Epson ET-2860 Series, ESC/P-R 2** (from the epson-escpr2/escpr package).

For the Lexmark (driverless IPP):

```
ipp://10.8.0.6/printers/Lexmark
```

Select driver: **IPP Everywhere**.

**Command line:**

```bash
lpadmin -p Epson-ET-2860 \
  -E \
  -v ipp://10.8.0.6/printers/Epson-ET-2860 \
  -m epson-inkjet-printer-escpr2/Epson-ET-2860_Series-epson-escpr2-en.ppd \
  -o PageSize=A4

lpadmin -p Lexmark \
  -E \
  -v ipp://10.8.0.6/printers/Lexmark \
  -m everywhere \
  -o PageSize=A4

lpoptions -d Epson-ET-2860
```

Verify:

```bash
lpstat -p Epson-ET-2860
lpstat -p Lexmark
```

---

### Test print

```bash
echo "test" | lp -d Epson-ET-2860
echo "test" | lp -d Lexmark
```

---

## Troubleshooting

**Printer not found via Avahi:** check the cups VM is running on mireo:

```bash
ssh root@mireo systemctl status microvm@cups
```

**`ipp://10.8.0.6` unreachable:** you need to be on the `10.8.0.0/24` LAN (wired or Wi-Fi through mireo) or connected via Tailscale.

**Wrong PPD / driver not found:** list available Epson models:

```bash
lpinfo -m | grep -i ET-2860
```

Use whatever path that returns as the `-m` argument to `lpadmin`.

**Job stuck in queue:** check the cups VM directly:

```bash
ssh root@cups lpstat -t
ssh root@cups lpq
```
