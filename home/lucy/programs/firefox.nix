{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.firefox.enable {
    programs.firefox = {
      profiles.${config.home.username} = {
        isDefault = true;
        settings = {
          "browser.compactmode.show" = true;
          "browser.newtabpage.enabled" = false;
          "browser.startup.homepage" = "about:blank";
          "browser.tabs.inTitlebar" = 1;
          "browser.toolbars.bookmarks.visibility" = "never";
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "browser.uidensity" = 1;
          "sidebar.revamp" = false;
        };
        userChrome = ''
          :root {
            --toolbar-bgcolor: rgba(26, 20, 35, 0.88) !important;
            --toolbar-color: #f0d0f5 !important;
            --toolbar-field-background-color: rgba(42, 36, 54, 0.88) !important;
            --toolbar-field-color: #f0d0f5 !important;
            --tab-selected-bgcolor: #ff1493 !important;
            --tab-selected-textcolor: #ffffff !important;
          }

          #navigator-toolbox {
            background: transparent !important;
            border: none !important;
          }

          #TabsToolbar {
            padding-inline: 10px !important;
            padding-top: 8px !important;
          }

          .tabbrowser-tab {
            min-height: 34px !important;
            padding-inline: 4px !important;
          }

          .tab-background {
            border-radius: 14px !important;
            margin-block: 4px 2px !important;
          }

          #nav-bar {
            margin: 0 12px 12px !important;
            border-radius: 16px !important;
            box-shadow: 0 10px 28px rgba(12, 7, 18, 0.25) !important;
          }

          #urlbar-background,
          .searchbar-textbox {
            border-radius: 14px !important;
          }
        '';
      };
    };

    stylix.targets.firefox.profileNames = [config.home.username];
  };
}
