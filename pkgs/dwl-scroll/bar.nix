# Keep dwlb's appearance tied to the compositor palette, including custom colors.
{
  pkgs,
  settings,
}: let
  inherit (pkgs) lib;
  inherit (settings) colors;
  args = [
    "-no-ipc"
    # Connection names/SSIDs are external data, not dwlb inline shell commands.
    "-no-status-commands"
    "-font"
    "Iosevka,Symbols Nerd Font Mono:size=10"
    "-vertical-padding"
    "4"
    "-active-fg-color"
    colors.root
    "-active-bg-color"
    colors.focus
    "-occupied-fg-color"
    colors.focus
    "-occupied-bg-color"
    colors.border
    "-inactive-fg-color"
    colors.focus
    "-inactive-bg-color"
    colors.root
    "-urgent-fg-color"
    colors.root
    "-urgent-bg-color"
    colors.urgent
    "-middle-bg-color"
    colors.root
    "-middle-bg-color-selected"
    colors.root
    "-no-active-color-title"
  ];
in
  pkgs.writeShellScriptBin "dwl-scroll-bar" ''
    exec ${lib.getExe pkgs.dwlb} ${lib.escapeShellArgs args} "$@"
  ''
