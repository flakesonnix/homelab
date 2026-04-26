{ config, lib, ... }:

{
  options.lucy.thunderbirdUi = {
    enable = lib.mkEnableOption "Thunderbird UI customization";
  };

  config = lib.mkIf config.lucy.thunderbirdUi.enable {
    home.file.".thunderbird/ptixzkzl.default/user.js".text = ''
      user_pref("mail.tabs.autoHide", false);
      user_pref("mail.uidensity", 1);
      user_pref("mail.pane_config.dynamic", 0);
      user_pref("mailnews.start_page.enabled", false);
      user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
    '';

    home.file.".thunderbird/ptixzkzl.default/chrome/userChrome.css".text = ''
      :root {
        --toolbar-bgcolor: #1a1423 !important;
        --toolbar-color: #f0d0f5 !important;
        --lwt-accent-color: #1a1423 !important;
        --lwt-text-color: #f0d0f5 !important;
      }

      #toolbar-menubar,
      #tabs-toolbar,
      #mail-bar3,
      #folderPaneHeaderBar,
      #threadPaneHeaderBar {
        background: #1a1423 !important;
        color: #f0d0f5 !important;
      }

      #tabmail-tabs .tabmail-tab {
        border-radius: 12px !important;
        margin: 4px 4px 0 !important;
      }
    '';
  };
}
