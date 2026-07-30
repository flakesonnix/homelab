{ lib, ... }: {
  # --- Internet gateway ---
  nodes.internet = {
    name = "Internet";
    deviceType = "internet";
    icon = "devices.cloud";
  };

  # --- Mireo: extra services not auto-detected ---
  nodes.mireo.deviceType = lib.mkForce "router";
  nodes.mireo.services = {
    netdata = {
      name = "Netdata";
      info = "10.8.0.1:19999";
    };
    nfs = {
      name = "NFS";
      info = "/data → 10.8.0.0/24";
    };
    iventoy = {
      name = "iVentoy PXE";
      info = "proxyDHCP :26000";
    };
  };

  # --- Yammat VM: manual service (no extractor) ---
  nodes.yammat = {
    deviceType = "nixos";
    services.yammat = {
      name = "YAMMAT";
      info = "10.8.0.5:3000";
    };
  };

  # --- CUPS VM: manual service (no extractor) ---
  nodes.cups = {
    deviceType = "nixos";
    services.cups = {
      name = "CUPS";
      info = "Epson ET-2860 · 10.8.0.6:631";
    };
  };

  # --- SSH keys VM ---
  nodes.sshkeys = {
    deviceType = "nixos";
    services.sshkeys = {
      name = "SSH Public Keys";
      info = "10.8.0.7:80";
    };
  };

  # --- APT cache VM ---
  nodes.aptcache = {
    deviceType = "nixos";
    services.aptcache = {
      name = "apt-cacher-ng";
      info = "10.8.0.8:3142";
    };
  };

  # --- Monerod VM: manual service (tor auto-detected, monerod is not) ---
  nodes.monerod = {
    deviceType = "nixos";
    services.monerod = {
      name = "Monerod";
      info = "10.8.0.4:18080 (pruned)";
    };
  };
}
