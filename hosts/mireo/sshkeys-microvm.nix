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
      system.stateVersion = "25.11";
      networking.hostName = "sshkeys";
      networking.firewall.allowedTCPPorts = [22 80];

      users.users.root.openssh.authorizedKeys.keys = [keys.lucy.servers];
      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "yes";
      };

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

      microvm = {
        hypervisor = "qemu";
        mem = 256;
        vcpu = 1;
        interfaces = [
          {
            type = "tap";
            id = "vm-sshkeys";
            mac = "02:00:00:10:08:07";
          }
        ];
        shares = [
          {
            proto = "virtiofs";
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }
        ];
      };

      systemd.network.enable = true;
      systemd.network.networks."20-lan" = {
        matchConfig.Type = "ether";
        address = ["10.8.0.7/24"];
        networkConfig = {
          Gateway = "10.8.0.1";
          DNS = ["10.8.0.1"];
          DHCP = "no";
          IPv6AcceptRA = false;
        };
      };
    };
  };
}
