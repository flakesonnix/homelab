{
  config,
  lib,
  ...
}: {
  options.programs.virtManager.enable = lib.mkEnableOption "virt-manager with pre-seeded mireo remote connection";

  config = lib.mkIf config.programs.virtManager.enable {
    # Lokal (qemu:///system, p53 libvirtd) + remote mireo
    # (qemu+ssh://root@10.8.0.1/system). Beide vorseeden + autoconnect,
    # damit die GUI direkt verbunden öffnet.
    dconf.settings = {
      "org/virt-manager/virt-manager/connections" = {
        uris = ["qemu:///system" "qemu+ssh://root@10.8.0.1/system"];
        autoconnect = ["qemu:///system" "qemu+ssh://root@10.8.0.1/system"];
      };
    };
  };
}
