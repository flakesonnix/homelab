# Dashboard VM (microVM on br0, behind Caddy on mireo).
# Homepage (gethomepage.dev, Homarr-Ersatz — Homarr ist nicht in nixpkgs,
# Homepage ist voll deklarativ: Kacheln/Widgets als YAML im Store).
# Alle Homelab-Dienste als Kacheln; tote Links beleben sich, sobald die
# jeweiligen Stub-VMs echte Dienste bekommen. Erreichbar via
# http://dash.home.arpa (Caddy -> :8082).
{lib, ...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "dash";
      ip = (import ./vm-ips.nix).dash;
      mem = 1024;
      vcpu = 1;
      tcpPorts = [22 8082];
      volumes = [
        {
          image = "dash-data.img";
          mountPoint = "/var/lib/homepage-dashboard";
          size = 512;
          user = "dash";
          group = "dash";
        }
      ];
      config = {
        users.users.dash = {
          isSystemUser = true;
          group = "dash";
        };
        users.groups.dash = {};
        # Upstream nutzt DynamicUser + StateDirectory — das beißt sich mit
        # dem gemounteten Volume (Exit 238, selbe Falle wie uptime-kuma/lldap).
        # Statischer User wie in lldap-microvm.nix.
        systemd.services.homepage-dashboard.serviceConfig = {
          DynamicUser = lib.mkForce false;
          User = "dash";
          Group = "dash";
        };
        services.homepage-dashboard = {
          enable = true;
          listenPort = 8082;
          allowedHosts = "localhost:8082,127.0.0.1:8082,dash.home.arpa,10.8.0.32:8082";
          settings = {
            title = "Homelab";
            description = "Homelab Dashboard";
            theme = "dark";
            color = "slate";
          };
          widgets = [
            {
              resources = {
                cpu = true;
                memory = true;
                disk = "/";
              };
            }
            {
              search = {
                provider = "duckduckgo";
                target = "_blank";
              };
            }
          ];
          services = [
            {
              Media = [
                {
                  Jellyfin = {
                    icon = "jellyfin";
                    href = "http://jellyfin.home.arpa";
                    description = "Filme, Serien, Musik";
                  };
                }
                {
                  Kodi = {
                    icon = "kodi";
                    href = "http://kodi.home.arpa";
                    description = "Musikbox (Behringer)";
                  };
                }
                {
                  Immich = {
                    icon = "immich";
                    href = "https://10.8.0.21";
                    description = "Fotos";
                  };
                }
              ];
            }
            {
              Monitoring = [
                {
                  Grafana = {
                    icon = "grafana";
                    href = "http://grafana.home.arpa";
                    description = "Metriken";
                  };
                }
                {
                  Prometheus = {
                    icon = "prometheus";
                    href = "http://prometheus.home.arpa";
                    description = "Monitoring-Backend";
                  };
                }
                {
                  Uptime-Kuma = {
                    icon = "uptime-kuma";
                    href = "http://uptime-kuma.home.arpa";
                    description = "Status + Monitore";
                  };
                }
                {
                  Status = {
                    icon = "uptime-kuma";
                    href = "http://status.home.arpa";
                    description = "Öffentliche Statusseite";
                  };
                }
              ];
            }
            {
              Identity = [
                {
                  LLDAP = {
                    icon = "lldap";
                    href = "http://lldap.home.arpa";
                    description = "Benutzerverzeichnis";
                  };
                }
                {
                  Pocket-ID = {
                    icon = "keycloak";
                    href = "http://pocket-id.home.arpa";
                    description = "SSO-Login";
                  };
                }
              ];
            }
            {
              Apps = [
                {
                  Nextcloud = {
                    icon = "nextcloud";
                    href = "https://10.8.0.14";
                    description = "Dateien";
                  };
                }
                {
                  Paperless = {
                    icon = "paperless-ngx";
                    href = "http://10.8.0.22";
                    description = "Dokumente";
                  };
                }
                {
                  ntfy = {
                    icon = "ntfy";
                    href = "http://10.8.0.24";
                    description = "Push-Nachrichten";
                  };
                }
                {
                  Syncthing = {
                    icon = "syncthing";
                    href = "http://10.8.0.26:8384";
                    description = "Sync";
                  };
                }
                {
                  Woodpecker = {
                    icon = "woodpecker-ci";
                    href = "http://10.8.0.17";
                    description = "CI";
                  };
                }
                {
                  NetBox = {
                    icon = "netbox";
                    href = "https://10.8.0.15";
                    description = "Inventar";
                  };
                }
                {
                  Yammat = {
                    icon = "calendar";
                    href = "http://yammat.home.arpa";
                    description = "Events";
                  };
                }
              ];
            }
            {
              System = [
                {
                  CUPS = {
                    icon = "printer";
                    href = "http://cups.home.arpa";
                    description = "Drucken";
                  };
                }
                {
                  SSH-Keys = {
                    icon = "key";
                    href = "http://sshkeys.home.arpa";
                    description = "Public Keys";
                  };
                }
                {
                  AdGuard = {
                    icon = "adguard-home";
                    href = "http://10.8.0.30:3000";
                    description = "DNS-Filter";
                  };
                }
              ];
            }
          ];
          bookmarks = [
            {
              Homelab = [
                {
                  db210-org = [
                    {
                      abbr = "db";
                      href = "https://db210.org/";
                    }
                  ];
                }
              ];
            }
          ];
        };
      };
    })
  ];
}
