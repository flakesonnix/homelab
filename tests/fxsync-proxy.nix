{
  pkgs,
  lib,
  self,
  ...
}: let
  host = self.nixosConfigurations.mireo.config;
  guest = host.microvm.vms.fxsync.config.config;
  vhosts = host.services.caddy.virtualHosts;
  backend = pkgs.writeText "fxsync-backend.py" ''
    import json
    from http.server import BaseHTTPRequestHandler, HTTPServer

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            body = json.dumps({
                "host": self.headers.get("Host"),
                "proto": self.headers.get("X-Forwarded-Proto"),
                "path": self.path,
            }).encode()
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    HTTPServer(("10.8.0.31", 5000), Handler).serve_forever()
  '';
in
  assert !(vhosts ? "http://fxsync.home.arpa");
  assert guest.services.firefox-syncserver.singleNode.url == "https://fxsync.home.arpa";
  assert guest.networking.firewall.backend == "iptables";
  assert guest.networking.firewall.allowedTCPPorts == [22];
  assert guest.networking.firewall.trustedInterfaces == ["lo"];
  assert lib.hasInfix "-s 10.8.0.1 --dport 5000 -j nixos-fw-accept" guest.networking.firewall.extraCommands;
  assert lib.hasInfix "-s fd00:cafe:1::1 --dport 5000 -j nixos-fw-accept" guest.networking.firewall.extraCommands;
  assert lib.elem "fxsync.home.arpa,fxsync,10.8.0.1,fd00:cafe:1::1" host.services.dnsmasq.settings.host-record;
  assert lib.elem "fxsync.home.arpa" host.microvm.vms.dns.config.config.networking.hosts."10.8.0.1";
  assert lib.elem "fxsync.home.arpa" host.microvm.vms.dns.config.config.networking.hosts."fd00:cafe:1::1";
  assert host.microvm.vms.dns.config.config.networking.hosts."10.8.0.31" == [];
  assert host.microvm.vms.dns.config.config.networking.hosts."fd00:cafe:1::31" == [];
    pkgs.testers.runNixOSTest {
      name = "fxsync-proxy";

      nodes = {
        server = {
          networking.interfaces.eth1 = {
            ipv4.addresses = [
              {
                address = "10.8.0.1";
                prefixLength = 24;
              }
              {
                address = "10.8.0.31";
                prefixLength = 24;
              }
              {
                address = "192.0.2.1";
                prefixLength = 24;
              }
            ];
            ipv6.addresses = [
              {
                address = "fd00:cafe:1::1";
                prefixLength = 64;
              }
              {
                address = "fd00:dead::1";
                prefixLength = 64;
              }
            ];
          };
          networking.firewall = {
            allowedTCPPorts = [80 443];
            inherit (guest.networking.firewall) extraCommands;
          };
          services.caddy = {
            enable = true;
            virtualHosts."https://fxsync.home.arpa" = vhosts."https://fxsync.home.arpa";
          };
          systemd.services.fxsync-backend = {
            wantedBy = ["multi-user.target"];
            wants = ["network-online.target"];
            after = ["network-online.target"];
            serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 ${backend}";
          };
          environment.systemPackages = [pkgs.curl];
        };
        client = {
          networking.interfaces.eth1 = {
            ipv4.addresses = [
              {
                address = "10.8.0.100";
                prefixLength = 24;
              }
              {
                address = "192.0.2.2";
                prefixLength = 24;
              }
            ];
            ipv6.addresses = [
              {
                address = "fd00:cafe:1::100";
                prefixLength = 64;
              }
              {
                address = "fd00:dead::2";
                prefixLength = 64;
              }
            ];
          };
          environment.systemPackages = [pkgs.curl];
        };
      };

      testScript = ''
        import json

        start_all()
        server.wait_for_unit("fxsync-backend.service")
        server.wait_for_unit("caddy.service")
        server.wait_for_open_port(443)
        server.wait_until_succeeds("test -f /var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt")

        with subtest("an untrusted client rejects the internal CA"):
            status, _ = client.execute("curl --noproxy '*' --max-time 10 --resolve fxsync.home.arpa:443:10.8.0.1 https://fxsync.home.arpa/")
            assert status == 60, f"expected certificate verification failure, got {status}"

        # Only a disposable fixture's public certificate is copied, never a key.
        server.succeed("cp /var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt /tmp/fxsync-root.crt")
        server.copy_from_machine("/tmp/fxsync-root.crt")
        client.copy_from_host(str(server.out_dir / "fxsync-root.crt"), "/tmp/fxsync-root.crt")

        def request(machine, address, source, headers=""):
            target = f"[{address}]" if ":" in address else address
            output = machine.succeed(
                f"curl --noproxy '*' --max-time 10 --cacert /tmp/fxsync-root.crt "
                f"--resolve fxsync.home.arpa:443:{target} --interface {source} "
                f"{headers} -sS -w '\\n%{{http_code}}' "
                "'https://fxsync.home.arpa/1.0/sync/1.5?fixture=1'"
            )
            return output.rsplit("\n", 1)

        with subtest("trusted loopback and LAN clients reach the unchanged backend URL"):
            for machine, address, source in [
                (server, "127.0.0.1", "127.0.0.1"),
                (server, "::1", "::1"),
                (client, "10.8.0.1", "10.8.0.100"),
                (client, "fd00:cafe:1::1", "fd00:cafe:1::100"),
            ]:
                body, code = request(machine, address, source)
                assert code == "200", (body, code)
                assert json.loads(body) == {
                    "host": "fxsync.home.arpa",
                    "proto": "https",
                    "path": "/1.0/sync/1.5?fixture=1",
                }

        with subtest("non-LAN peers cannot spoof the source allowlist"):
            for address, source in [("192.0.2.1", "192.0.2.2"), ("fd00:dead::1", "fd00:dead::2")]:
                for headers in ["", "-H 'X-Forwarded-For: 10.8.0.100' -H 'Forwarded: for=127.0.0.1'"]:
                    _, code = request(client, address, source, headers)
                    assert code == "403", code

        with subtest("HTTP never proxies credentials or backend data"):
            result = server.succeed("curl --noproxy '*' --max-time 10 --resolve fxsync.home.arpa:80:127.0.0.1 -sS -o /dev/null -w '%{http_code}' http://fxsync.home.arpa/1.0/sync/1.5")
            assert result == "308", result

        with subtest("other LAN clients cannot bypass Caddy on port 5000"):
            client.fail("curl --noproxy '*' --max-time 3 --interface 10.8.0.100 http://10.8.0.31:5000/")
      '';
    }
