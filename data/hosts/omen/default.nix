{
  lib,
  pkgs,
}: {
  presets = import ./presets.nix;
  moduleFlags = import ./module-flags.nix;

  inherit ((import ./packages.nix {inherit pkgs;})) packageToggles basePackages fontPackages;

  settings = lib.foldl' lib.recursiveUpdate {} [
    (import ./settings.nix)
    (import ./power.nix)
    (import ./services.nix)
  ];
}
