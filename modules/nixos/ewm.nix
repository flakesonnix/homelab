{
  lib,
  config,
  pkgs,
  ewm,
  ...
}: let
  cfg = config.lucy.ewm;
  # EWM builds against its own locked nixpkgs (see flake.nix): ours is
  # older and lacks libdisplay-info 0.3. Everything EWM-related comes
  # from that one consistent package set.
  ewmNixpkgs = ewm.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  ewmPkg = ewm.packages.${pkgs.stdenv.hostPlatform.system}.default;
  lockCommand = "${config.systemd.package}/bin/systemctl --user start ewm-lock.service";
  lockConfig = pkgs.writeText "ewm-lock.el" ''
    (setopt ewm-idle nil)
  '';
in {
  options.lucy.ewm = {
    enable = lib.mkEnableOption "EWM Emacs Wayland Manager session";
  };

  config = lib.mkIf cfg.enable {
    programs.ewm = {
      enable = true;
      # Both package options point at the same build: service.nix keeps
      # `package` (defaulting to its own `ewmPackage`) as a legacy alias.
      package = ewmPkg;
      ewmPackage = ewmPkg;
      emacsPackage = ewmNixpkgs.emacs-pgtk.pkgs.withPackages (_: [ewmPkg]);
      extraEmacsArgs = "--load ${lockConfig}";
    };

    security.pam.services.swaylock = {};

    # Upstream has ewm.service (Type=notify), not ewm-session.target.
    # It imports WAYLAND_DISPLAY before READY=1; never start these in GNOME.
    systemd.user.services.ewm-idle = {
      description = "Idle and suspend locking for EWM";
      wantedBy = ["ewm.service"];
      requisite = ["ewm.service"];
      partOf = ["ewm.service"];
      after = ["ewm.service"];
      unitConfig.ConditionEnvironment = ["XDG_CURRENT_DESKTOP=ewm" "WAYLAND_DISPLAY"];
      path = [pkgs.bash];
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.swayidle} -C /dev/null -w timeout 300 '${lockCommand}' before-sleep '${lockCommand}' lock '${lockCommand}'";
        Restart = "on-failure";
      };
    };

    systemd.user.services.ewm-lock = {
      description = "Single screen locker for EWM";
      requisite = ["ewm.service"];
      partOf = ["ewm.service"];
      after = ["ewm.service"];
      unitConfig.ConditionEnvironment = ["XDG_CURRENT_DESKTOP=ewm" "WAYLAND_DISPLAY"];
      serviceConfig = {
        Type = "notify";
        NotifyAccess = "all";
      };
      # systemctl start waits for the compositor's lock acknowledgement,
      # including concurrent requests. Keep swaylock foreground under systemd.
      script = ''
        exec ${lib.getExe pkgs.swaylock} --config /dev/null --ready-fd 3 \
          3> >(IFS= read -r && ${config.systemd.package}/bin/systemd-notify --ready)
      '';
    };

    # Runtime dependencies from the EWM wiki: clipboard integration plus
    # the volume/brightness tools used by the default keybindings.
    # System packages cannot collide with `nix profile` installs the way
    # Home Manager home.packages can.
    environment.systemPackages = with pkgs; [
      wl-clipboard
      brightnessctl
    ];
  };
}
