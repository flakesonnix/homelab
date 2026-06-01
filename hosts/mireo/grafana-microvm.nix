{...}: let
  dashboard = builtins.toJSON {
    annotations.list = [];
    editable = true;
    graphTooltip = 1;
    id = null;
    links = [];
    liveNow = false;
    panels = [
      {
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        fieldConfig.defaults = {
          color.mode = "palette-classic";
          unit = "Mbps";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 0;
        };
        id = 1;
        options.legend = {
          displayMode = "list";
          placement = "bottom";
        };
        targets = [
          {
            expr = "rate(node_network_receive_bytes_total{instance=\"router\",device=\"enp4s0\"}[5m]) * 8 / 1000000";
            legendFormat = "WAN RX";
            refId = "A";
          }
          {
            expr = "rate(node_network_transmit_bytes_total{instance=\"router\",device=\"enp4s0\"}[5m]) * 8 / 1000000";
            legendFormat = "WAN TX";
            refId = "B";
          }
        ];
        title = "WAN Throughput";
        type = "timeseries";
      }
      {
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        fieldConfig.defaults = {
          color.mode = "palette-classic";
          unit = "Mbps";
        };
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 0;
        };
        id = 2;
        options.legend = {
          displayMode = "list";
          placement = "bottom";
        };
        targets = [
          {
            expr = "rate(node_network_receive_bytes_total{instance=\"router\",device=\"br0\"}[5m]) * 8 / 1000000";
            legendFormat = "LAN RX";
            refId = "A";
          }
          {
            expr = "rate(node_network_transmit_bytes_total{instance=\"router\",device=\"br0\"}[5m]) * 8 / 1000000";
            legendFormat = "LAN TX";
            refId = "B";
          }
        ];
        title = "LAN Bridge Throughput";
        type = "timeseries";
      }
      {
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        fieldConfig.defaults = {
          color.mode = "thresholds";
          max = 100;
          min = 0;
          thresholds = {
            mode = "absolute";
            steps = [
              {
                color = "green";
                value = null;
              }
              {
                color = "orange";
                value = 70;
              }
              {
                color = "red";
                value = 90;
              }
            ];
          };
          unit = "percent";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 0;
          y = 8;
        };
        id = 3;
        options = {
          colorMode = "value";
          graphMode = "area";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "(1 - avg(rate(node_cpu_seconds_total{instance=\"router\",mode=\"idle\"}[5m]))) * 100";
            refId = "A";
          }
        ];
        title = "CPU Usage";
        type = "stat";
      }
      {
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        fieldConfig.defaults = {
          color.mode = "thresholds";
          max = 100;
          min = 0;
          thresholds = {
            mode = "absolute";
            steps = [
              {
                color = "green";
                value = null;
              }
              {
                color = "orange";
                value = 70;
              }
              {
                color = "red";
                value = 90;
              }
            ];
          };
          unit = "percent";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 6;
          y = 8;
        };
        id = 4;
        options = {
          colorMode = "value";
          graphMode = "area";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "(1 - (node_memory_MemAvailable_bytes{instance=\"router\"} / node_memory_MemTotal_bytes{instance=\"router\"})) * 100";
            refId = "A";
          }
        ];
        title = "Memory Used";
        type = "stat";
      }
      {
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        fieldConfig.defaults = {
          color.mode = "thresholds";
          max = 100;
          min = 0;
          thresholds = {
            mode = "absolute";
            steps = [
              {
                color = "green";
                value = null;
              }
              {
                color = "orange";
                value = 70;
              }
              {
                color = "red";
                value = 90;
              }
            ];
          };
          unit = "percent";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 12;
          y = 8;
        };
        id = 5;
        options = {
          colorMode = "value";
          graphMode = "area";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "(1 - (node_filesystem_avail_bytes{instance=\"router\",mountpoint=\"/\",fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{instance=\"router\",mountpoint=\"/\",fstype!~\"tmpfs|overlay\"})) * 100";
            refId = "A";
          }
        ];
        title = "Disk Used /";
        type = "stat";
      }
      {
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        fieldConfig.defaults = {
          color.mode = "thresholds";
          thresholds = {
            mode = "absolute";
            steps = [
              {
                color = "green";
                value = null;
              }
              {
                color = "orange";
                value = 2;
              }
              {
                color = "red";
                value = 4;
              }
            ];
          };
          unit = "none";
        };
        gridPos = {
          h = 6;
          w = 6;
          x = 18;
          y = 8;
        };
        id = 6;
        options = {
          colorMode = "value";
          graphMode = "area";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "node_load5{instance=\"router\"}";
            refId = "A";
          }
        ];
        title = "Load 5m";
        type = "stat";
      }
      {
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        fieldConfig.defaults = {
          color.mode = "palette-classic";
          unit = "Mbps";
        };
        gridPos = {
          h = 8;
          w = 24;
          x = 0;
          y = 14;
        };
        id = 7;
        options.legend = {
          displayMode = "list";
          placement = "bottom";
        };
        targets = [
          {
            expr = "rate(node_network_receive_bytes_total{host!=\"mireo\",device!~\"lo|tailscale.*|br.*|vm.*\"}[5m]) * 8 / 1000000";
            legendFormat = "{{host}} {{device}} RX";
            refId = "A";
          }
          {
            expr = "rate(node_network_transmit_bytes_total{host!=\"mireo\",device!~\"lo|tailscale.*|br.*|vm.*\"}[5m]) * 8 / 1000000";
            legendFormat = "{{host}} {{device}} TX";
            refId = "B";
          }
        ];
        title = "Host Traffic";
        type = "timeseries";
      }
      {
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        fieldConfig.defaults = {
          color.mode = "thresholds";
          thresholds.mode = "absolute";
          thresholds.steps = [
            {
              color = "blue";
              value = null;
            }
          ];
          unit = "decbytes";
        };
        gridPos = {
          h = 4;
          w = 6;
          x = 0;
          y = 22;
        };
        id = 8;
        options = {
          colorMode = "value";
          graphMode = "none";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "increase(node_network_receive_bytes_total{instance=\"router\",device=\"enp4s0\"}[24h])";
            refId = "A";
          }
        ];
        title = "WAN RX Today";
        type = "stat";
      }
      {
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        fieldConfig.defaults = {
          color.mode = "thresholds";
          thresholds.mode = "absolute";
          thresholds.steps = [
            {
              color = "blue";
              value = null;
            }
          ];
          unit = "decbytes";
        };
        gridPos = {
          h = 4;
          w = 6;
          x = 6;
          y = 22;
        };
        id = 9;
        options = {
          colorMode = "value";
          graphMode = "none";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "increase(node_network_transmit_bytes_total{instance=\"router\",device=\"enp4s0\"}[24h])";
            refId = "A";
          }
        ];
        title = "WAN TX Today";
        type = "stat";
      }
      {
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        fieldConfig.defaults = {
          color.mode = "thresholds";
          thresholds.mode = "absolute";
          thresholds.steps = [
            {
              color = "blue";
              value = null;
            }
          ];
          unit = "decbytes";
        };
        gridPos = {
          h = 4;
          w = 6;
          x = 12;
          y = 22;
        };
        id = 10;
        options = {
          colorMode = "value";
          graphMode = "none";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "increase(node_network_receive_bytes_total{instance=\"router\",device=\"enp4s0\"}[30d])";
            refId = "A";
          }
        ];
        title = "WAN RX 30d";
        type = "stat";
      }
      {
        datasource = {
          type = "prometheus";
          uid = "prometheus";
        };
        fieldConfig.defaults = {
          color.mode = "thresholds";
          thresholds.mode = "absolute";
          thresholds.steps = [
            {
              color = "blue";
              value = null;
            }
          ];
          unit = "decbytes";
        };
        gridPos = {
          h = 4;
          w = 6;
          x = 18;
          y = 22;
        };
        id = 11;
        options = {
          colorMode = "value";
          graphMode = "none";
          justifyMode = "auto";
          orientation = "auto";
          reduceOptions = {
            calcs = ["lastNotNull"];
            fields = "";
            values = false;
          };
        };
        targets = [
          {
            expr = "increase(node_network_transmit_bytes_total{instance=\"router\",device=\"enp4s0\"}[30d])";
            refId = "A";
          }
        ];
        title = "WAN TX 30d";
        type = "stat";
      }
    ];
    refresh = "10s";
    schemaVersion = 39;
    style = "dark";
    tags = ["router" "mireo"];
    templating.list = [];
    time = {
      from = "now-6h";
      to = "now";
    };
    timepicker = {};
    timezone = "browser";
    title = "Mireo Router";
    uid = "mireo-router";
    version = 1;
  };
in {

  systemd.network.networks."24-lan-microvm" = {
    matchConfig.Name = "vm-*";
    networkConfig.Bridge = "br0";
  };

  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "10.8.0.1";
    port = 9100;
  };

  microvm.autostart = ["grafana"];
  microvm.vms.grafana = {
    autostart = true;
    config = {
      imports = [
        (import ./microvm-base.nix {
          ip = "10.8.0.2";
          mac = "02:00:00:10:08:02";
          interfaceId = "vm-grafana";
        })
      ];

      networking.hostName = "grafana";
      networking.firewall.allowedTCPPorts = [22 3000 9090];

      microvm.mem = 768;
      microvm.vcpu = 2;
      microvm.volumes = [
        {
          image = "grafana-data.img";
          mountPoint = "/var/lib/grafana";
          size = 1024;
        }
        {
          image = "prometheus-data.img";
          mountPoint = "/var/lib/prometheus2";
          size = 1024;
        }
      ];

      systemd.tmpfiles.rules = [
        "d /var/lib/grafana 0750 grafana grafana -"
        "d /var/lib/prometheus2 0750 prometheus prometheus -"
      ];
      services.journald.extraConfig = ''
        ForwardToConsole=yes
        MaxLevelConsole=debug
      '';

      environment.etc."grafana-dashboards/mireo-router.json".text = dashboard;

      services.prometheus = {
        enable = true;
        port = 9090;
        scrapeConfigs = [
          {
            job_name = "router";
            static_configs = [
              {
                targets = ["10.8.0.1:9100"];
                labels = {
                  instance = "router";
                  host = "mireo";
                };
              }
            ];
          }
          {
            job_name = "hosts";
            static_configs = [
              {
                targets = ["10.8.0.176:9100"];
                labels = {
                  instance = "omen";
                  host = "omen";
                };
              }
              {
                targets = ["10.8.0.122:9100"];
                labels = {
                  instance = "p50";
                  host = "p50";
                };
              }
            ];
          }
        ];
      };

      services.grafana = {
        enable = true;
        dataDir = "/var/lib/grafana";
        settings = {
          analytics.reporting_enabled = false;
          server = {
            http_addr = "0.0.0.0";
            http_port = 3000;
            domain = "10.8.0.2";
          };
          users = {
            default_theme = "dark";
            viewers_can_edit = false;
          };
          "auth.anonymous" = {
            enabled = true;
            org_role = "Viewer";
          };
          security = {
            secret_key = "mireo-grafana-microvm-2026-05-20";
            disable_initial_admin_creation = false;
          };
        };
        provision = {
          enable = true;
          datasources.settings = {
            apiVersion = 1;
            datasources = [
              {
                access = "proxy";
                isDefault = true;
                name = "Prometheus";
                type = "prometheus";
                uid = "prometheus";
                url = "http://127.0.0.1:9090";
              }
            ];
          };
          dashboards.settings = {
            apiVersion = 1;
            providers = [
              {
                disableDeletion = false;
                editable = true;
                folder = "Router";
                name = "router";
                options.path = "/etc/grafana-dashboards";
                orgId = 1;
                type = "file";
              }
            ];
          };
        };
      };
    };
  };
}
