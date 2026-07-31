{...}: {
  imports = [
    (import ./mk-microvm.nix {
      name = "network-services";
      ip = "10.8.0.3";
      # interface id must stay <=15 chars (Linux IFNAMSIZ)
      interfaceId = "vm-net-services";
      mem = 384;
      vcpu = 1;
      tcpPorts = [53];
      udpPorts = [53];
      extraDns = ["1.1.1.1" "9.9.9.9"];
    })
  ];
}
