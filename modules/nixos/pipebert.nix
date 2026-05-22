{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lucy.pipebert;

  effectiveHostName =
    if config.networking.hostName != null && config.networking.hostName != ""
    then config.networking.hostName
    else cfg.hostName;

  rootHost =
    if cfg.domain == null
    then effectiveHostName
    else "${effectiveHostName}.${cfg.domain}";

  mopidyHost =
    if cfg.domain == null
    then "mopidy"
    else "mopidy.${cfg.domain}";

  ledfxHost =
    if cfg.domain == null
    then "ledfx"
    else "ledfx.${cfg.domain}";

  defaultMopidySettings = {
    audio.output = "pulsesink server=127.0.0.1";
    core.restore_state = true;
    file = {
      enabled = true;
      media_dirs = cfg.mediaDir;
    };
    iris = {
      country = "de";
      locale = "en_US";
    };
    mpd = {
      enabled = true;
      hostname = "::";
    };
    youtube = {
      allow_cache = true;
      youtube_dl_package = "yt_dlp";
    };
  };

  shairportConfig = (pkgs.formats.libconfig {}).generate "shairport-sync.conf" {
    diagnostics.log_verbosity = 1;
    general = {
      name = cfg.name;
      output_backend = "pw";
    };
  };

  splitCidrs = builtins.partition (cidr: builtins.match ".*:.*" cidr != null) cfg.allowedCidrs;
  allowedV6Cidrs = splitCidrs.right;
  allowedV4Cidrs = splitCidrs.wrong;
  pulseAuthCidrs =
    if cfg.allowedCidrs == []
    then ["0.0.0.0/0" "::/0"]
    else cfg.allowedCidrs;
  pulseTcpAuthAcl = lib.concatStringsSep ";" (["127.0.0.0/8"] ++ allowedV4Cidrs ++ lib.optionals (cfg.allowedCidrs == []) ["0.0.0.0/0"]);

  mkRule = family: cidrs: proto: portSpec: comment:
    if cidrs == []
    then ""
    else ''
      ${family} saddr { ${lib.concatStringsSep ", " cidrs} } ${proto} dport ${portSpec} accept comment ${lib.escapeShellArg comment}
    '';

  restrictedFirewallRules = lib.concatStringsSep "\n" (
    lib.filter (line: line != "") (
      [
        (mkRule "ip" allowedV4Cidrs "tcp" "4713" "pipebert pulse tcp")
        (mkRule "ip6" allowedV6Cidrs "tcp" "4713" "pipebert pulse tcp")
        (mkRule "ip" allowedV4Cidrs "udp" "5353" "pipebert mdns")
        (mkRule "ip6" allowedV6Cidrs "udp" "5353" "pipebert mdns")
        (mkRule "ip" allowedV4Cidrs "udp" "9875" "pipebert rtp")
        (mkRule "ip6" allowedV6Cidrs "udp" "9875" "pipebert rtp")
      ]
      ++ lib.optionals cfg.mopidy.enable [
        (mkRule "ip" allowedV4Cidrs "tcp" "6600" "pipebert mopidy mpd")
        (mkRule "ip6" allowedV6Cidrs "tcp" "6600" "pipebert mopidy mpd")
      ]
      ++ lib.optionals cfg.airplay.enable [
        (mkRule "ip" allowedV4Cidrs "tcp" "5000" "pipebert airplay")
        (mkRule "ip6" allowedV6Cidrs "tcp" "5000" "pipebert airplay")
        (mkRule "ip" allowedV4Cidrs "udp" "6001-6011" "pipebert airplay")
        (mkRule "ip6" allowedV6Cidrs "udp" "6001-6011" "pipebert airplay")
        (mkRule "ip" allowedV4Cidrs "tcp" "7000" "pipebert airplay2")
        (mkRule "ip6" allowedV6Cidrs "tcp" "7000" "pipebert airplay2")
        (mkRule "ip" allowedV4Cidrs "udp" "49152-60999" "pipebert airplay2")
        (mkRule "ip6" allowedV6Cidrs "udp" "49152-60999" "pipebert airplay2")
        (mkRule "ip" allowedV4Cidrs "udp" "319-320" "pipebert nqptp")
        (mkRule "ip6" allowedV6Cidrs "udp" "319-320" "pipebert nqptp")
      ]
    )
  );

  reloadUsbScript = pkgs.writeShellScript "pipebert-reload-usb" ''
    export PATH=${lib.makeBinPath [pkgs.coreutils pkgs.gawk pkgs.uhubctl pkgs.usbutils]}
    exec ${lib.getExe pkgs.bash} ${./pipebert/reload-usb.sh} ${lib.escapeShellArg cfg.usbDevice.vendorId} ${lib.escapeShellArg cfg.usbDevice.productId}
  '';

  landingPage = pkgs.writeTextDir "index.html" ''
    <!DOCTYPE html>
    <html lang="en">
      <body>
        <ul>
          ${lib.optionalString cfg.ledfx.enable ''<li><a href="https://${ledfxHost}/">LEDfx</a></li>''}
          ${lib.optionalString cfg.mopidy.enable ''<li><a href="https://${mopidyHost}/iris/">Mopidy</a></li>''}
          ${lib.optionalString cfg.mopidy.enable ''<li><a href="https://${mopidyHost}/youtube/">Mopidy YouTube</a></li>''}
        </ul>
      </body>
    </html>
  '';
in {
  options.lucy.pipebert = {
    enable = lib.mkEnableOption "Pipebert-style network audio receiver";

    user = lib.mkOption {
      type = lib.types.str;
      default = "lucy";
      description = "User that owns lingering user services like PipeWire, LEDfx, and Shairport Sync.";
    };

    hostName = lib.mkOption {
      type = lib.types.str;
      default = "pipebert";
      description = "Default hostname to use when host config does not set one already.";
    };

    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional domain used for generated virtual hosts.";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "Pipebert";
      description = "Advertised AirPlay and sink name.";
    };

    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/lucy/Music";
      description = "Directory Mopidy scans for local audio files.";
    };

    allowedCidrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "CIDRs allowed to reach Pipebert ports when source-restricted firewall rules are enabled.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open Pipebert service ports in the firewall. With `allowedCidrs = []`, ports are open to all sources.";
    };

    sinkNode = {
      enableRename = lib.mkEnableOption "rename the physical PipeWire sink node";

      nodeName = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Exact PipeWire node name to rename, e.g. `alsa_output.usb-...`.";
      };

      description = lib.mkOption {
        type = lib.types.str;
        default = "Pipebert Audio Streaming";
        description = "Friendly description shown for the renamed sink.";
      };
    };

    usbDevice = {
      enableReload = lib.mkEnableOption "cycle the USB audio device after PipeWire starts";

      vendorId = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "USB vendor ID used by the reload helper.";
      };

      productId = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "USB product ID used by the reload helper.";
      };
    };

    airplay.enable = (lib.mkEnableOption "Shairport Sync plus nqptp for AirPlay and AirPlay 2") // {default = true;};

    ledfx.enable = lib.mkEnableOption "LEDfx as a lingering user service";

    mopidy = {
      enable = (lib.mkEnableOption "Mopidy with Iris, MPD, and YouTube support") // {default = true;};

      extensionPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        description = "Extra Mopidy extension packages to install for the service.";
      };

      extraConfigFiles = lib.mkOption {
        type = lib.types.listOf (lib.types.oneOf [lib.types.path lib.types.str]);
        default = [];
        description = "Extra Mopidy config files, e.g. secrets managed via sops.";
      };

      extraSettings = lib.mkOption {
        type = lib.types.attrs;
        default = {};
        description = "Additional Mopidy settings merged on top of the module defaults.";
      };
    };

    web.enable = lib.mkEnableOption "landing page plus reverse proxies for Mopidy and LEDfx through Nginx";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.sinkNode.enableRename || cfg.sinkNode.nodeName != "";
        message = "lucy.pipebert.sinkNode.nodeName must be set when lucy.pipebert.sinkNode.enableRename = true.";
      }
      {
        assertion = !cfg.usbDevice.enableReload || (cfg.usbDevice.vendorId != "" && cfg.usbDevice.productId != "");
        message = "lucy.pipebert.usbDevice.vendorId and productId must be set when lucy.pipebert.usbDevice.enableReload = true.";
      }
    ];

    environment.systemPackages = with pkgs; [
      mpc
      ncmpcpp
      ncpamixer
      pulseaudio
      somafm-cli
      termsonic
    ];

    networking =
      {
        hostName = lib.mkDefault cfg.hostName;
        firewall = {
          allowedTCPPorts =
            if cfg.openFirewall && cfg.allowedCidrs == []
            then
              [4713]
              ++ lib.optionals cfg.mopidy.enable [6600]
              ++ lib.optionals cfg.airplay.enable [5000 7000]
            else [];
          allowedUDPPorts =
            if cfg.openFirewall && cfg.allowedCidrs == []
            then
              [5353 9875]
              ++ lib.optionals cfg.airplay.enable [319 320]
            else [];
          allowedUDPPortRanges =
            if cfg.openFirewall && cfg.allowedCidrs == []
            then
              lib.optionals cfg.airplay.enable [
                {
                  from = 6001;
                  to = 6011;
                }
                {
                  from = 49152;
                  to = 60999;
                }
              ]
            else [];
          extraInputRules =
            if cfg.openFirewall && cfg.allowedCidrs != []
            then restrictedFirewallRules
            else "";
        };
      }
      // lib.optionalAttrs (cfg.domain != null) {
        domain = lib.mkDefault cfg.domain;
      };

    security.rtkit.enable = lib.mkDefault true;

    users.users.${cfg.user}.linger = true;

    environment.etc = lib.mkIf cfg.airplay.enable {
      "shairport-sync.conf".source = shairportConfig;
    };

    services = {
      avahi = {
        enable = true;
        nssmdns4 = true;
        publish = {
          enable = true;
          addresses = true;
          userServices = true;
        };
      };

      pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
        wireplumber = {
          enable = true;
          extraConfig = lib.mkIf cfg.sinkNode.enableRename {
            "50-pipebert-rename" = {
              "monitor.alsa.rules" = [
                {
                  matches = [{"node.name" = cfg.sinkNode.nodeName;}];
                  actions."update-props"."node.description" = cfg.sinkNode.description;
                }
              ];
            };
          };
        };
        extraConfig = {
          pipewire.pipebert = {
            "context.modules" = [
              {
                name = "libpipewire-module-rtp-sap";
                args = {
                  "sess.ignore-ssrc" = true;
                  "source.ip" = "0.0.0.0";
                };
              }
            ];
          };
          pipewire-pulse.pipebert = {
            "pulse.cmd" = [
              {
                cmd = "load-module";
                args = "module-zeroconf-publish";
              }
              {
                cmd = "load-module";
                args = "module-native-protocol-tcp port=4713 listen=0.0.0.0 auth-ip-acl=${pulseTcpAuthAcl}";
              }
            ];
            "pulse.properties" = {
              "auth-ip-acl" = ["127.0.0.0/8" "::1/128"] ++ pulseAuthCidrs;
              "pulse.default.tlength" = "96000/48000";
              "server.address" = ["unix:native"];
            };
          };
        };
      };

      mopidy = lib.mkIf cfg.mopidy.enable {
        enable = true;
        settings = lib.recursiveUpdate defaultMopidySettings cfg.mopidy.extraSettings;
        extraConfigFiles = cfg.mopidy.extraConfigFiles;
        extensionPackages = with pkgs;
          [
            mopidy-iris
            mopidy-mpd
            mopidy-youtube
            python3Packages.yt-dlp
          ]
          ++ cfg.mopidy.extensionPackages;
      };

      nginx = lib.mkIf cfg.web.enable {
        enable = true;
        virtualHosts =
          {
            "${rootHost}" = {
              enableACME = true;
              forceSSL = true;
              locations."/".root = "${landingPage}/";
            };
          }
          // lib.optionalAttrs cfg.mopidy.enable {
            "${mopidyHost}" = {
              enableACME = true;
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://127.0.0.1:6680";
                proxyWebsockets = true;
              };
            };
          }
          // lib.optionalAttrs cfg.ledfx.enable {
            "${ledfxHost}" = {
              enableACME = true;
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://127.0.0.1:8888/";
                proxyWebsockets = true;
              };
            };
          };
      };

      udev.extraRules = lib.mkIf cfg.usbDevice.enableReload ''
        SUBSYSTEM=="usb", DRIVER=="usb", MODE="0664", GROUP="users"
        SUBSYSTEM=="usb", DRIVER=="usb", \
          RUN+="/bin/sh -c \"chown -f root:users $sys$devpath/*/disable || true\"", \
          RUN+="/bin/sh -c \"chmod -f 660 $sys$devpath/*/disable || true\""
      '';
    };

    systemd = lib.mkMerge [
      (lib.mkIf cfg.airplay.enable {
        packages = [pkgs.nqptp];
        services.nqptp = {
          serviceConfig.DynamicUser = true;
          wantedBy = ["multi-user.target"];
        };
        user.services.shairport-sync = {
          description = "Shairport Sync - AirPlay receiver";
          after = [
            "sound.target"
            "avahi-daemon.service"
            "network.target"
            "network-online.target"
          ];
          wants = ["network-online.target"];
          wantedBy = ["default.target"];
          serviceConfig = {
            ExecStart = lib.getExe (pkgs.shairport-sync.override {enableAirplay2 = true;});
            Restart = "on-failure";
            RuntimeDirectory = "shairport-sync";
          };
        };
      })
      {
        user.services = {
          ledfx = lib.mkIf cfg.ledfx.enable {
            after = ["pipewire.target"];
            wantedBy = ["default.target"];
            serviceConfig = {
              ExecStart = lib.getExe pkgs.ledfx;
              Restart = "on-failure";
            };
          };
          pipewire.serviceConfig =
            {
              RestartSec = "3s";
              StartLimitBurst = "10";
            }
            // lib.optionalAttrs cfg.usbDevice.enableReload {
              ExecStartPost = "-${lib.getExe pkgs.bash} ${reloadUsbScript}";
            };
        };
      }
    ];
  };
}
