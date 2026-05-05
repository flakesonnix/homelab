{
  config,
  lib,
  pkgs,
  ...
}: let
  colors = config.lib.stylix.colors.withHashtag;
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
        --accent-color: ${colors.base0D};
      }
    '';
  };
}
