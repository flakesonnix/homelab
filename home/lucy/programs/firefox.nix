{ config, lib, ... }:

{
  options.lucy.firefoxUi = {
    enable = lib.mkEnableOption "Firefox UI customization";
  };

  config = lib.mkIf config.lucy.firefoxUi.enable {
    home.file.".mozilla/firefox/lxnes0qr.default-release/user.js".text = ''
      user_pref("browser.compactmode.show", true);
      user_pref("browser.newtabpage.enabled", false);
      user_pref("browser.startup.homepage", "about:blank");
      user_pref("browser.tabs.inTitlebar", 1);
      user_pref("browser.toolbars.bookmarks.visibility", "never");
      user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
      user_pref("browser.uidensity", 1);
      user_pref("sidebar.revamp", false);
    '';

    home.file.".mozilla/firefox/lxnes0qr.default-release/chrome/userChrome.css".text = ''
      :root {
        --toolbar-bgcolor: #1a1423 !important;
        --toolbar-color: #f0d0f5 !important;
        --toolbar-field-background-color: #2a2436 !important;
        --toolbar-field-color: #f0d0f5 !important;
        --tab-selected-bgcolor: #ff1493 !important;
        --tab-selected-textcolor: #ffffff !important;
      }

      #TabsToolbar {
        padding-inline: 8px !important;
        padding-top: 6px !important;
      }

      .tabbrowser-tab {
        min-height: 34px !important;
        padding-inline: 4px !important;
      }

      .tab-background {
        border-radius: 12px !important;
        margin-block: 4px 2px !important;
      }

      #nav-bar {
        margin: 0 10px 10px !important;
        border-radius: 14px !important;
      }

      #urlbar-background,
      .searchbar-textbox {
        border-radius: 12px !important;
      }
    '';
  };
}
