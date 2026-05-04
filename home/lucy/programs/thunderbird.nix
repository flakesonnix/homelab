{
  config,
  lib,
  pkgs,
  frameworkLib,
  ...
}: {
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

      /* Dark theme colors */
      :root {
        --bg-color: #1e1e2e;
        --fg-color: #cdd6f4;
        --accent-color: #89b4fa;
      }
    '';
  };
}
