{lib, pkgs, ...}: let
  keys = import ../../ssh-public-keys.nix {inherit lib;};
in {
  systemd.network.networks."28-lan-microvm-sshkeys" = {
    matchConfig.Name = "vm-sshkeys";
    networkConfig.Bridge = "br0";
  };

  microvm.autostart = ["sshkeys"];

  microvm.vms.sshkeys = {
    autostart = true;
    config = {
      imports = [
        (import ./microvm-base.nix {
          ip = "10.8.0.7";
          mac = "02:00:00:10:08:07";
          interfaceId = "vm-sshkeys";
        })
      ];

      networking.hostName = "sshkeys";
      networking.firewall.allowedTCPPorts = [22 80];

      microvm.mem = 256;
      microvm.vcpu = 1;

      services.nginx = {
        enable = true;
        virtualHosts."_" = {
          root = pkgs.runCommand "ssh-public-keys" {} ''
            mkdir -p $out
            cp ${../../keys}/*.pub $out/
            chmod 644 $out/*
          '';
          locations."/".extraConfig = "autoindex on;";
        };
      };
    };
  };
}
