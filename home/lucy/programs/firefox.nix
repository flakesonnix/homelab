{
  config,
  lib,
  frameworkLib,
  ...
}: let
  theme = frameworkLib.theme.fromStylix config;
  inherit (theme) colors gradient;
in {
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
          "browser.download.useDownloadDir" = false;
          "browser.download.always_ask_before_handling_new_types" = true;
          "browser.shell.checkDefaultBrowser" = false;
          "browser.startup.page" = 0;
          "browser.tabs.closeWindowWithLastTab" = false;
          "browser.tabs.loadDivertedInBackground" = true;
          "browser.link.open_newwindow" = 3;
          "browser.urlbar.showSearchSuggestionsFirst" = false;
          "browser.urlbar.autoFill" = false;

          # NVIDIA + XWayland freeze fixes
          "widget.dmabuf.enabled" = false;
          "gfx.x11-egl.force-disabled" = true;
          "media.ffmpeg.vaapi.enabled" = false;

          "privacy.donottrackheader.enabled" = true;
          "privacy.trackingprotection.enabled" = true;
          "privacy.trackingprotection.socialtracking.enabled" = true;
          "network.cookie.cookieBehavior" = 1;
          "permissions.default.camera" = 2;
          "permissions.default.microphone" = 2;
          "permissions.default.geo" = 2;
          "permissions.default.notification" = 2;
        };
        userChrome = ''
          :root {
            --toolbar-bgcolor: ${colors.base00}e0 !important;
            --toolbar-color: ${colors.base05} !important;
            --toolbar-field-background-color: ${colors.base01}e0 !important;
            --toolbar-field-color: ${colors.base05} !important;
            --tab-selected-bgcolor: ${colors.base0E} !important;
            --tab-selected-textcolor: ${colors.base00} !important;
            --toolbarbutton-icon-fill: ${colors.base05} !important;
            --lwt-accent-color: ${colors.base00} !important;
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

          .tabbrowser-tab[selected="true"] .tab-background {
            background: ${gradient "90deg" [colors.base0E colors.base0D colors.base0C]} !important;
            box-shadow: 0 0 16px ${colors.base0E}66 !important;
          }

          .tabbrowser-tab:hover .tab-background {
            background: ${colors.base02}cc !important;
          }

          #nav-bar {
            margin: 0 12px 12px !important;
            border-radius: 16px !important;
            border: 1px solid ${colors.base0E}44 !important;
            box-shadow: 0 10px 28px ${colors.base00}40 !important;
          }

          #urlbar-background,
          .searchbar-textbox {
            border-radius: 14px !important;
          }

          /* Hide elements */
          #appMenu-button,
          #chat-button,
          #calendar-button,
          #tasks-button {
            display: none !important;
          }
        '';
      };
    };

    stylix.targets.firefox.profileNames = [config.home.username];
  };
}
