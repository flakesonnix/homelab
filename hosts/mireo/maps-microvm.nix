# Maps microVM: OpenStreetMap stack
# Nominatim, OSRM, tiles, large CPU/storage footprint.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "maps";
      ip = (import ./vm-ips.nix).osm;
      mem = 8192;
      vcpu = 8;
      tcpPorts = [22 80 443];
      volumes = [
        {
          image = "osm-planet.img";
          mountPoint = "/data/osm/planet";
          size = 32768;
          user = "osm";
          group = "osm";
        }
        {
          image = "osm-tiles.img";
          mountPoint = "/data/osm/tiles";
          size = 8192;
          user = "osm";
          group = "osm";
        }
      ];
      tmpfiles = [
        "d /data/osm 0750 osm osm - -"
        "d /data/osm/planet 0750 osm osm - -"
        "d /data/osm/tiles 0750 osm osm - -"
      ];
      config = {
        imports = [(import ../../modules/nixos/osm.nix)];
        lucy.services.osm = {
          enable = true;
          dataDir = "/data/osm";
          region = "germany";
          postgresDatabase = "osm";
        };
      };
    })
  ];
}
