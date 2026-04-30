{pkgs}: {
  presets = import ./presets.nix;
  moduleFlags = import ./module-flags.nix;

  inherit ((import ./packages.nix {inherit pkgs;})) packageToggles basePackages fontPackages;

  settings = import ./settings.nix;
}
