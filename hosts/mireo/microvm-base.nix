# Common NixOS module for all mireo microvms.
# Usage: imports = [ (import ./microvm-base.nix { ip = "10.8.0.X"; mac = "02:00:00:..."; interfaceId = "vm-name"; }) ];
{ ip, mac, interfaceId, extraDns ? [] }:
{ lib, ... }:
let
  keys = import ../../ssh-public-keys.nix {inherit lib;};
in {
  system.stateVersion = "25.11";

  users.users.root.openssh.authorizedKeys.keys = [keys.lucy.servers];
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  microvm.hypervisor = "qemu";
  microvm.interfaces = [
    {
      type = "tap";
      id = interfaceId;
      inherit mac;
    }
  ];
  microvm.shares = [
    {
      proto = "virtiofs";
      tag = "ro-store";
      source = "/nix/store";
      mountPoint = "/nix/.ro-store";
    }
  ];

  systemd.network.enable = true;
  systemd.network.networks."20-lan" = {
    matchConfig.Type = "ether";
    address = ["${ip}/24"];
    networkConfig = {
      Gateway = "10.8.0.1";
      DNS = ["10.8.0.1"] ++ extraDns;
      DHCP = "no";
      IPv6AcceptRA = false;
    };
  };
}
