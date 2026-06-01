{ lib, ... }: {
  # --- Internet gateway ---
  topology.nodes.internet = {
    name = "Internet";
    deviceType = "internet";
    icon = "devices.cloud";
  };

  # --- Mireo: extra services not auto-detected ---
  topology.nodes.mireo.services = {
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
  topology.nodes.yammat.services = {
    yammat = {
      name = "YAMMAT";
      info = "10.8.0.5:3000";
    };
  };

  # --- CUPS VM: manual service (no extractor) ---
  topology.nodes.cups.services = {
    cups = {
      name = "CUPS";
      info = "Epson ET-2860 · 10.8.0.6:631";
    };
  };

  # --- Monerod VM: manual service (tor auto-detected, monerod is not) ---
  topology.nodes.monerod.services = {
    monerod = {
      name = "Monerod";
      info = "10.8.0.4:18080 (pruned)";
    };
  };
}
