{ config, lib, pkgs, ... }:

{
  options.lucy.openclaude = {
    enable = lib.mkEnableOption "OpenClaude CLI";
  };

  config = lib.mkIf config.lucy.openclaude.enable {
    home.packages = [ pkgs.nodejs ];

    home.activation.installOpenclaude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.nodejs}/bin/npm install -g @gitlawb/openclaude 2>/dev/null || true
    '';

    xdg.configFile."openclaude/config.json".text = builtins.toJSON {
      mcpServers = {
        firefox = {
          command = "npx";
          args = [ "-y" "firefox-devtools-mcp" ];
        };
        jetbrains = {
          command = "npx";
          args = [ "-y" "@jetbrains/mcp-proxy" ];
        };
      };
    };
  };
}
