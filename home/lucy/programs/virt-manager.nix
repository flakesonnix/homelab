{
  config,
  lib,
  ...
}: {
  options.programs.virtManager.enable = lib.mkEnableOption "virt-manager with pre-seeded mireo remote connection";

  config = lib.mkIf config.programs.virtManager.enable {
    # Remote-only use: local libvirtd stays disabled (x270 TPM workaround),
    # virt-manager talks to mireo via qemu+ssh://root@10.8.0.1/system.
    # Pre-seed + autoconnect so the GUI opens already connected.
    dconf.settings = {
      "org/virt-manager/virt-manager/connections" = {
        uris = ["qemu+ssh://root@10.8.0.1/system"];
        autoconnect = ["qemu+ssh://root@10.8.0.1/system"];
      };
    };
  };
}
