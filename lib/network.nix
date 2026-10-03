{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types mkForce;
  inherit (import ../../lib/types.nix {inherit lib;}) checked siteSpec deviceSpec;
in {
  # ── mkDNSRecord ─────────────────────────────────────────
  # Generates a dnsmasq host-record entry.
  mkDNSRecord = {
    name,
    ip,
    domain ? "home.arpa",
    ...
  }: "${name}.${domain},${name},${ip},fd00:cafe:1::${builtins.elemAt (lib.splitString "." ip) 3}";

  # ── mkDNSZone ───────────────────────────────────────────
  # Generates dnsmasq configuration from a set of host records.
  mkDNSZone = {
    domain,
    hosts,
    ...
  }: {
    domain = domain;
    expand-hosts = true;
    local = "/${domain}/";
    host-record = hosts;
  };

  # ── mkAdGuardHome ───────────────────────────────────────
  # Generates AdGuard Home DNS configuration declaratively.
  mkAdGuardHome = {
    domain,
    upstream,
    blocklists ? [],
    ...
  }: {
    services.adguardhome = {
      enable = true;
      hostname = domain;
      tls = {
        enabled = true;
        port = 443;
      };
      dns = {
        bindHosts = ["0.0.0.0:53"];
        upstream = upstream;
        blocklists = blocklists;
      };
    };
  };

  # ── mkNetworkDevice ─────────────────────────────────────
  # Generates a NetBox/LibreNMS device entry from a device spec.
  mkNetworkDevice = spec: let
    s = checked deviceSpec spec;
  in {
    name = s.name;
    site = s.site;
    role = s.role;
    manufacturer = s.manufacturer;
    model = s.model;
    interfaces = s.interfaces;
    addresses = s.addresses;
    tags = s.tags;
    snmpCommunity = s.snmpCommunity;
  };

  # ── mkNetworkSite ───────────────────────────────────────
  # Generates a network site VLAN configuration.
  mkNetworkSite = spec: let
    s = checked siteSpec spec;
  in {
    name = s.name;
    vlan = s.vlan;
    gateway = s.gateway;
    prefix = s.prefix;
    dns = s.dns;
  };

  # ── mkNetboxReconciler ──────────────────────────────────
  # Creates a systemd service that syncs Nix device inventory
  # to NetBox via REST API. Idempotent: Nix state wins.
  mkNetboxReconciler = {
    name,
    apiUrl,
    tokenSecret,
    devices,
    ...
  }: {
    systemd.services."netbox-reconcile-${name}" = {
      description = "Reconcile NetBox inventory for ${name} (idempotent)";
      after = ["netbox.service"];
      requires = ["netbox.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      environment = {
        NETBOX_URL = apiUrl;
        NETBOX_TOKEN_FILE = "/run/secrets/${tokenSecret}";
      };
      path = with pkgs; [curl jq];
      script = ''
        set -eu
        token=$(cat "$NETBOX_TOKEN_FILE")
        devices_json='${builtins.toJSON devices}'
        echo "$devices_json" | jq -c '.[]' | while read -r device; do
          name=$(jq -r '.name' <<<"$device")
          curl -sf -X PUT "$NETBOX_URL/api/dcim/devices/" \
            -H "Authorization: Token $token" \
            -H "Content-Type: application/json" \
            -d "$device" || \
          curl -sf -X POST "$NETBOX_URL/api/dcim/devices/" \
            -H "Authorization: Token $token" \
            -H "Content-Type: application/json" \
            -d "$device" || true
        done
      '';
    };
  };

  # ── mkLibrenmsReconciler ────────────────────────────────
  # Creates a systemd service that syncs devices to LibreNMS.
  mkLibrenmsReconciler = {
    name,
    apiUrl,
    apiKeySecret,
    devices,
    ...
  }: {
    systemd.services."librenms-reconcile-${name}" = {
      description = "Reconcile LibreNMS devices for ${name} (idempotent)";
      after = ["librenms.service"];
      requires = ["librenms.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      environment = {
        LIBRENMS_API_URL = apiUrl;
        LIBRENMS_API_KEY_FILE = "/run/secrets/${apiKeySecret}";
      };
      path = with pkgs; [curl jq];
      script = ''
        set -eu
        key=$(cat "$LIBRENMS_API_KEY_FILE")
        devices_json='${builtins.toJSON devices}'
        echo "$devices_json" | jq -c '.[]' | while read -r device; do
          hostname=$(jq -r '.hostname // .name' <<<"$device")
          curl -sf -X POST "$LIBRENMS_API_URL/api/v0/devices" \
            -H "X-Auth-Token: $key" \
            -H "Content-Type: application/json" \
            -d "{\"hostname\": \"$hostname\"}" || true
        done
      '';
    };
  };

  # ── mkSNMPConfig ────────────────────────────────────────
  # Generates net-snmp configuration from a list of SNMP specs.
  mkSNMPConfig = {
    community,
    devices,
    ...
  }: {
    services.net-snmp = {
      enable = true;
      readonlyCommunity = community;
      extraConfig = ''
        rocommunity ${community}
      '';
    };
  };
}
