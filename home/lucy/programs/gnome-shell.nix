{
  config,
  lib,
  ...
}: {
  options.programs.gnomeShell.enable = lib.mkEnableOption "GNOME Shell extensions (dash-to-dock + systray)";

  config = lib.mkIf config.programs.gnomeShell.enable {
    # Ohne das ignoriert Home-Manager dconf.settings stillschweigend
    # (trifft auch gnome-theme.nix / virt-manager.nix).
    dconf.enable = true;

    dconf.settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = [
          "dash-to-dock@micxgx.gmail.com"
          "appindicatorsupport@rgcjonas.gmail.com"
          "caffeine@patapon.info"
          "user-theme@gnome-shell-extensions.gcampax.github.com"
          "vicinae@dagimg-dot"
        ];
      };

      # Ubuntu-ähnliches Dock unten, weicht Fenstern bei Überlappung.
      "org/gnome/shell/extensions/dash-to-dock" = {
        dock-position = lib.mkDefault "BOTTOM";
        extend-height = lib.mkDefault true;
        dash-max-icon-size = lib.mkDefault 48;
        autohide = lib.mkDefault false;
        intellihide = lib.mkDefault true;
        show-trash = lib.mkDefault false;
      };
    };
  };
}
