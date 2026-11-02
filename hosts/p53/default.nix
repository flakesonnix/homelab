{
  nixos-hardware,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./host.nix
    # Platte pendelt zwischen X270 und P50: beide ThinkPad-Profile laden.
    # Aktuell läuft die Kiste auf dem P50 (i7-6700HQ, Intel + Nouveau).
    nixos-hardware.nixosModules.lenovo-thinkpad-x270
    nixos-hardware.nixosModules.lenovo-thinkpad-p50
    # p53 ist ein Single-User-Laptop: lucy (wheel) darf run0/sudo ohne
    # interaktive polkit-Authentifizierung nutzen, damit
    # `nixos-rebuild switch` (-> sudo nix-env --set) nicht an
    # "Access denied: interactive authentication required" scheitert.
    ({ lib, ... }: {
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (subject.local && subject.active && subject.isInGroup("wheel")) {
            return polkit.Result.YES;
          }
        });
      '';
    })
  ];

  # NixOS generates shared module indexes; v4l2loopback's own depmod collides.
  boot.kernelPackages = pkgs.linuxPackages.extend (
    _: prev: {
      v4l2loopback = prev.v4l2loopback.overrideAttrs (old: {
        makeFlags = old.makeFlags ++ [ "DEPMOD=true" ];
      });
    }
  );
}
