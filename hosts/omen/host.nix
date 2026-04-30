{
  lib,
  pkgs,
  wrappers,
  ...
}: let
  projectLib = import ../../lib;
  hostData = import ../../data/hosts/omen.nix {inherit pkgs;};

  hyfetch-wrapped = wrappers.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.hyfetch;
    flags = {
      "-p" = "transgender";
    };
  };
in {
  config =
    projectLib.framework.host.applyHost {
      inherit lib;
      host = hostData;
      packagePath = ["lucy"];
      basePackagePath = ["lucy" "basePackages"];
    }
    // {
      hardware.nvidia.powerManagement.enable = lib.mkForce false;

      lucy.base.sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS";
      lucy.base.sshKeyComment = "lucy@p50";

      environment.systemPackages = [hyfetch-wrapped];
      fonts.packages = with pkgs; [hack-font];
    };
}
