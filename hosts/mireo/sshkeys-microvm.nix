{
  lib,
  pkgs,
  ...
}: let
  keys = import ../../ssh-public-keys.nix {inherit lib;};
in {
  imports = [
    (import ./mk-microvm.nix {
      name = "sshkeys";
      ip = (import ./vm-ips.nix).sshkeys;
      mem = 256;
      vcpu = 1;
      tcpPorts = [22 80];
      config = {
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
    })
  ];
}
