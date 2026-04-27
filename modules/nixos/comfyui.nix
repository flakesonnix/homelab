{
  lib,
  config,
  comfyui-nix,
  ...
}: {
  imports = [comfyui-nix.nixosModules.default];

  options.lucy.comfyui = {
    enable = lib.mkEnableOption "ComfyUI AI image generation";
    gpuSupport = lib.mkOption {
      type = lib.types.enum ["none" "cuda" "rocm"];
      default = "cuda";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8188;
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf config.lucy.comfyui.enable {
    nixpkgs.overlays = [comfyui-nix.overlays.default];
    services.comfyui = {
      enable = true;
      inherit (config.lucy.comfyui) gpuSupport port openFirewall;
    };
  };
}
