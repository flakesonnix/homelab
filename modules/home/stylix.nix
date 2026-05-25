{
  lib,
  config,
  pkgs,
  ...
}: {
  config = lib.mkIf config.stylix.enable {
    home.pointerCursor.package = lib.mkDefault (pkgs.callPackage ../../home/lucy/cursors/default.nix {});
    stylix = {
      polarity = lib.mkDefault "dark";
      targets = {
        waybar.enable = true;
        alacritty.enable = false;
        gtk.enable = true;
        bat.enable = true;
        btop.enable = true;
        fzf.enable = true;
        mako.enable = false;
        rofi.enable = false;
        zathura.enable = false;
        firefox.enable = true;
      };
    };

    gtk = {
      enable = true;
    };

    home.activation.removeLegacyKvantumSymlink = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      kvantum_dir="$HOME/.config/Kvantum/Base16Kvantum"

      if [ -L "$kvantum_dir" ]; then
        run rm -f "$kvantum_dir"
      fi
    '';
  };
}
