{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: let
  theme = frameworkLib.theme.fromStylix config;
  inherit (theme) colors gradient;
in {
  config = lib.mkIf config.programs.thunderbird.enable {
    home.packages = [pkgs.thunderbird];

    xdg.configFile."thunderbird/userChrome.css".text = ''
      /* Thunderbird userChrome.css */
      @namespace url("http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul");

      /* Hide unnecessary elements */
      #button-appmenu,
      #button-chat,
      #button-address,
      #button-calendar,
      #button-tasks {
        display: none !important;
      }

      /* Compact view */
      treechildren::-moz-tree-row {
        height: 24px !important;
      }

      :root {
        --bg-color: ${colors.base00};
        --fg-color: ${colors.base05};
        --accent-color: ${colors.base0E};
      }

      #navigation-toolbox,
      #toolbar-menubar {
        background: ${gradient "90deg" [colors.base00 colors.base01 colors.base02]} !important;
        color: ${colors.base05} !important;
      }

      #folderTree treechildren::-moz-tree-row(selected),
      #threadTree treechildren::-moz-tree-row(selected) {
        background: ${colors.base0E} !important;
      }
    '';
  };
}
