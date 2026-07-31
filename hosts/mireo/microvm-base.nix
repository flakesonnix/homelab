# Common NixOS module for all mireo microvms.
# Usage: imports = [ (import ./microvm-base.nix { ip = "10.8.0.6"; interfaceId = "vm-cups"; }) ];
{
  ip,
  interfaceId,
  extraDns ? [],
}: {lib, ...}: let
  keys = import ../../ssh-public-keys.nix {inherit lib;};
  hexDigit = d: builtins.elemAt ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c" "d" "e" "f"] d;
  mac = let
    lastOctet = lib.toInt (lib.last (lib.splitString "." ip));
  in "02:00:00:10:08:${hexDigit (builtins.div lastOctet 16)}${hexDigit (lib.mod lastOctet 16)}";
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
