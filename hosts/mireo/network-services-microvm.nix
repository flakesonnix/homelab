# Reservierter Stub (noch keine Dienste).
# DHCP/DNS/PXE leben auf dem mireo-HOST (dnsmasq + Pixiecore in
# data/hosts/mireo/settings.nix), NICHT hier — ein zweiter DHCP-Server auf
# br0 würde mit dem Host um Leases raufen. Diese Reservierung pinnt nur
# 10.8.0.3 + den DNS-Namen für künftige Netzdienste.
{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "network-services";
      ip = (import ./vm-ips.nix)."network-services";
      # interface id must stay <=15 chars (Linux IFNAMSIZ)
      interfaceId = "vm-net-services";
      mem = 384;
      vcpu = 1;
    })
  ];
}
