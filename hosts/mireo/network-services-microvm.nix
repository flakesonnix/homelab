{pkgs, ...}: let
  netbootxyzArm64 = pkgs.fetchurl {
    url = "https://github.com/netbootxyz/netboot.xyz/releases/download/2.0.88/netboot.xyz-arm64.efi";
    sha256 = "sha256-AeW92FU65XVJKGPi+A/iz7Jvtb7wKIO3xG3Cx7v4kRg=";
  };
in {
  networking.hosts."10.8.0.3" = ["network-services" "dhcp-pxe"];

  systemd.network.networks."25-lan-microvm" = {
    matchConfig.Name = "vm-net-services";
    networkConfig.Bridge = "br0";
  };

  microvm.autostart = [
    "grafana"
    "network-services"
  ];

  microvm.vms.network-services = {
    autostart = true;
    config = {
      system.stateVersion = "25.11";
      networking.hostName = "network-services";
      networking.firewall.allowedUDPPorts = [53 67 69 4011];
      networking.firewall.allowedTCPPorts = [53];

      users.users.root.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAT5LcBzQCMfPyq0t29vGjz6UCcTXKZWROmUy82A0lrS"
      ];
      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "yes";
      };

      microvm = {
        hypervisor = "qemu";
        mem = 384;
        vcpu = 1;
        interfaces = [
          {
            type = "tap";
            id = "vm-net-services";
            mac = "02:00:00:10:08:03";
          }
        ];
        shares = [
          {
            proto = "virtiofs";
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
          }
        ];
      };

      systemd.network.enable = true;
      systemd.network.networks."20-lan" = {
        matchConfig.Type = "ether";
        address = ["10.8.0.3/24"];
        networkConfig = {
          Gateway = "10.8.0.1";
          DNS = ["10.8.0.1" "1.1.1.1" "9.9.9.9"];
          DHCP = "no";
          IPv6AcceptRA = false;
        };
      };

      environment.etc = {
        "netboot/undionly.kpxe".source = "${pkgs.ipxe}/undionly.kpxe";
        "netboot/ipxe.efi".source = "${pkgs.ipxe}/ipxe.efi";
        "netboot/netboot.xyz.efi".source = "${pkgs.netbootxyz-efi}";
        "netboot/netboot.xyz-arm64.efi".source = netbootxyzArm64;
        "netboot/menu.ipxe".text = ''
          #!ipxe
          menu mireo netboot
          item netbootxyz  netboot.xyz
          item shell       iPXE shell
          item reboot      Reboot
          item exit        Exit back to firmware
          choose --default netbootxyz --timeout 5000 target && goto ''${target}

          :netbootxyz
          chain https://boot.netboot.xyz/menu.ipxe

          :shell
          shell

          :reboot
          reboot

          :exit
          exit
        '';
      };

      services.dnsmasq = {
        enable = true;
        settings = {
          bind-dynamic = true;
          except-interface = "lo";
          domain-needed = true;
          bogus-priv = true;
          dhcp-authoritative = true;
          dhcp-range = ["10.8.0.100,10.8.0.199,255.255.255.0,24h"];
          dhcp-option = [
            "option:router,10.8.0.1"
            "option:dns-server,10.8.0.1"
          ];
          dhcp-host = [
            "84:2a:fd:4e:bd:7e,omen,10.8.0.176"
            "50:7b:9d:e8:86:9a,p50,10.8.0.122"
            "00:1d:72:9e:25:83,x61,10.8.0.163"
            "d0:50:99:95:7b:13,client-124,10.8.0.124"
          ];
          enable-tftp = true;
          tftp-root = "/etc/netboot";
          dhcp-userclass = ["set:ipxe,iPXE"];
          dhcp-match = [
            "set:efiarm64,option:client-arch,11"
            "set:efi64,option:client-arch,7"
            "set:efi64,option:client-arch,9"
          ];
          dhcp-boot = [
            "tag:ipxe,menu.ipxe"
            "tag:efiarm64,netboot.xyz-arm64.efi"
            "tag:efi64,ipxe.efi"
            "tag:!efi64,undionly.kpxe"
          ];
          server = ["1.1.1.1" "9.9.9.9"];
        };
      };
    };
  };
}
