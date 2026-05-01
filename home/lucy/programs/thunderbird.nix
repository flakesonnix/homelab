{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.thunderbird.enable {
    programs.thunderbird = {
      profiles.${config.home.username} = {
        isDefault = true;
        settings = {
          "mail.tabs.autoHide" = false;
          "mail.uidensity" = 1;
          "mail.pane_config.dynamic" = 0;
          "mailnews.start_page.enabled" = false;
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        };
        userChrome = ''
          :root {
            --toolbar-bgcolor: rgba(26, 20, 35, 0.88) !important;
            --toolbar-color: #f0d0f5 !important;
            --lwt-accent-color: rgba(26, 20, 35, 0.88) !important;
            --lwt-text-color: #f0d0f5 !important;
          }

          #toolbar-menubar,
          #tabs-toolbar,
          #mail-bar3,
          #folderPaneHeaderBar,
          #threadPaneHeaderBar {
            background: transparent !important;
            color: #f0d0f5 !important;
          }

          #navigation-toolbox,
          #mail-bar3 {
            margin: 8px 12px 10px !important;
            padding: 2px 8px !important;
            border-radius: 16px !important;
            background: rgba(26, 20, 35, 0.88) !important;
            box-shadow: 0 10px 28px rgba(12, 7, 18, 0.24) !important;
          }

          #tabmail-tabs .tabmail-tab {
            border-radius: 14px !important;
            margin: 4px 4px 0 !important;
          }
        '';
      };
    };
  };
}
