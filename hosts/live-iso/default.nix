{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./host.nix
    ../../modules/nixos/cups.nix
  ];
}
