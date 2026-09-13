# Secrets

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix) using [age](https://age-encryption.org/) keys.

## How it works

1. An age key pair is generated per environment. The private key lives on the target host at `/etc/sops/age/keys.txt`.
2. The public key is registered in `.sops.yaml`, which tells SOPS which key can decrypt each secrets file.
3. `hosts/<host>/secrets.yaml` is an encrypted YAML file checked into the repo. Only the holder of the matching private key can decrypt it.
4. sops-nix decrypts the file at activation time and exposes secrets as files under `/run/secrets/`.

## Initial setup

```bash
# Generate age key pair (stores private key in .sops/keys.txt)
nix run .#setup-sops x270

# Update .sops.yaml with the printed public key, then create the secrets file
SOPS_AGE_KEY_FILE=.sops/keys.txt sops hosts/x270/secrets.yaml
```

The script outputs the public key and the exact `.sops.yaml` snippet to add. Current `.sops.yaml` covers `hosts/.*/secrets.yaml`.

## Deploy private key to host

```bash
sudo mkdir -p /etc/sops/age
sudo cp .sops/keys.txt /etc/sops/age/keys.txt
sudo chmod 600 /etc/sops/age/keys.txt
```

The `.sops/keys.txt` file is in `.gitignore` — never commit private keys.

## Using the module

`modules/nixos/sops.nix` wraps sops-nix with a simpler interface:

```nix
lucy.secrets = {
  enable = true;
  sopsFile = ./secrets.yaml;          # path to encrypted file
  ageKeyPath = /etc/sops/age/keys.txt; # default, usually omit
};
```

The module asserts `sopsFile != null` when enabled, so missing config surfaces as a clear eval error rather than a runtime failure.

## Asterisk secrets

When `services.asteriskLocal.secrets.enable = true`, phone passwords are kept out of the Nix store. The pjsip.conf and extensions.conf are rendered as sops templates with password placeholders resolved at activation time.

Requires `lucy.secrets.enable = true` (or `sops.defaultSopsFile` set directly).

Each phone's `passwordSecret` value is the sops secret key, e.g.:

```nix
services.asteriskLocal = {
  secrets.enable = true;
  phones.saal1 = {
    extension = "1001";
    passwordSecret = "asterisk/phones/saal1";
  };
};
```

The corresponding entry in `secrets.yaml`:

```yaml
asterisk:
  phones:
    saal1: "mysecretpassword"
```

## Editing secrets

```bash
SOPS_AGE_KEY_FILE=.sops/keys.txt sops hosts/x270/secrets.yaml
```

SOPS opens the decrypted file in `$EDITOR`, re-encrypts on save.

## Initrd SSH unlock keys

`lucy.base` enables SSH in the initrd (port 2222 by default) for LUKS-style remote unlock. It uses a host key at `/etc/secrets/initrd/ssh_host_ed25519_key`, which must exist on the host (it is not managed declaratively):

```bash
sudo mkdir -p /etc/secrets/initrd
sudo ssh-keygen -t ed25519 -f /etc/secrets/initrd/ssh_host_ed25519_key -N ""
sudo chmod 600 /etc/secrets/initrd/ssh_host_ed25519_key
```

Authorized keys match the root account's `authorized_keys` (i.e. `lucy.base.sshKey`).

## Key rotation

1. Generate new key: `nix run .#setup-sops x270` (will error if key exists — delete `.sops/keys.txt` first)
2. Update public key in `.sops.yaml`
3. Re-encrypt all affected secrets files: `SOPS_AGE_KEY_FILE=<old-key> sops updatekeys hosts/x270/secrets.yaml`
4. Deploy new private key to host, rebuild

## WireGuard keys (mireo ↔ purrgate transit)

Transit network `10.66.0.0/30`: purrgate `.1`, mireo `.2`. Private keys live
only in sops (`hosts/<host>/secrets.yaml`, encrypted); peer public keys and
the purrgate endpoint are plain settings in `data/hosts/mireo/settings.nix`.

### First-time setup (mireo)

Prerequisite: the age private key must already be at
`/etc/sops/age/keys.txt` on mireo — `lucy.secrets.enable = true` makes
activation fail without it. Deploy the key first (see above), then:

```bash
# 1. Generate the mireo WireGuard keypair and store the private key in sops.
#    Run this yourself — the key never leaves your machine (0600 temp file,
#    encrypted in place, shredded afterwards; only the public key is printed):
./scripts/setup-wireguard-mireo.sh
# Manual alternative: wg genkey | tee /tmp/mireo-wg-priv | wg pubkey,
# then SOPS_AGE_KEY_FILE=.sops/keys.txt sops hosts/mireo/secrets.yaml
# (wireguard -> mireo-private-key), then shred -u /tmp/mireo-wg-priv.

# 3. Fill the peer fields in data/hosts/mireo/settings.nix:
#    - peers[0].publicKey = <purrgate `wg pubkey` output>
#    - peers[0].endpoint  = <purrgate public IPv4>:51820
#    Keep allowedIPs = ["10.66.0.1/32"] — never 0.0.0.0/0 here (would hijack
#    the default route and break LAN/NFS/IPv6/microVMs).

# 4. Deploy and restart the tunnel
nix run .#deploy-mireo
ssh root@10.8.0.1 'systemctl restart wireguard-wg0 && wg show wg0'
```

Expected `wg show wg0`: `latest handshake` within the last minute,
`transfer` counters increasing (mireo sends `persistentKeepalive = 25`
through the FritzBox NAT).

### Published vs internal traffic

Public (via purrgate DNAT → wg0, firewall `networking.firewall.interfaces.wg0`):

- `80/tcp`, `443/tcp` — HTTP/HTTPS (reverse proxy on mireo)
- `25565/tcp+udp` — Minecraft example

Internal-only, never via wg0 (bound to `br0`/`10.8.0.0/24`, firewall drops
them on `wg0`, Avahi pinned to `br0`+`lo`):

- NFS `/data` (export `10.8.0.0/24` only), DHCP, LAN DNS, PXE/iVentoy `:26000`,
  Avahi/mDNS, Netdata `:19999` (bind `10.8.0.1`), nixfleet `:8443`, MicroVM
  internals.

### Outbound via VPS (opt-in, default off)

mireo keeps its FritzBox default route. Routing selected home services out
through the VPS public IPv4 requires explicit policy routing (separate table,
`ip rule from <service-IP> lookup 100`, `default via 10.66.0.1 table 100`).
Do not set `0.0.0.0/0` in `allowedIPs` — that would silently reroute all
mireo/LAN/VM traffic and break NFS, IPv6, and internal DNS.

### Rollback

- Tunnel misbehaving: `ssh root@10.8.0.1 'systemctl stop wireguard-wg0'` —
  LAN/NAT/dnsmasq/NFS are untouched (wg0 carries no LAN traffic).
- Remove entirely: delete the `networking.wireguard.interfaces.wg0` block and
  set `lucy.secrets.enable = false` in `data/hosts/mireo/settings.nix`, then
  `nix run .#deploy-mireo`.
- Rotate a compromised WG key: new `wg genkey`, update sops + peer's
  `publicKey`, restart both ends. No age-key rotation needed.
