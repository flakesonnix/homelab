{
  lib,
  pkgs,
  wrappers,
}: {
  systemPackages = let
    hyfetch-wrapped = wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.hyfetch;
      flags = {
        "-p" = "transgender";
      };
    };
  in [hyfetch-wrapped];

  presets = import ./presets.nix;
  moduleFlags = import ./module-flags.nix;

  inherit ((import ./packages.nix {inherit pkgs;})) packageToggles basePackages fontPackages;

  settings = lib.foldl' lib.recursiveUpdate {} [
    (import ./settings.nix)
    (import ./power.nix)
    (import ./services.nix)
    {
      hardware.nvidia.powerManagement.enable = lib.mkForce false;
    }
  ];
}
