{
  description = "Experimental NixBSD for the ThinkPad P53";

  inputs.nixbsd.url = "github:nix-community/nixbsd/8cf417b68b3426f6f4a3fcafdaf2fa3dfde0195d";

  outputs = {nixbsd, ...}: let
    system = nixbsd.lib.nixbsdSystem {
      modules = [./configuration.nix];
    };
    linuxBuild = system.extendModules {
      modules = [{nixpkgs.buildPlatform = "x86_64-linux";}];
    };
    inherit (linuxBuild) config;
    pkgs = linuxBuild.pkgs.pkgsBuildBuild;
  in {
    nixosConfigurations.p53 = system;

    packages.x86_64-linux = {
      default = config.system.build.systemImage;
      image = config.system.build.systemImage;
      vm = config.system.build.vm;
    };

    apps.x86_64-linux.default = {
      type = "app";
      program = "${config.system.build.vm}/bin/run-${config.system.name}-vm";
      meta.description = "Run the isolated NixBSD P53 test VM";
    };

    checks.x86_64-linux.configuration = assert config.nixpkgs.hostPlatform.system == "x86_64-freebsd";
    assert config.nixpkgs.buildPlatform.system == "x86_64-linux";
    assert config.boot.loader.stand-freebsd.enable;
    assert config.fileSystems."/".fsType == "ufs";
    assert config.fileSystems."/boot".fsType == "msdosfs";
    assert config.users.mutableUsers;
    assert config.users.users.root.initialHashedPassword == "";
    assert config.users.users.lucy.initialHashedPassword == "!";
    assert !(config.users.users ? bestie);
    assert !config.services.openssh.enable;
    assert !config.services.xserver.enable;
    assert config.virtualisation.vmVariant.fileSystems."/boot".device == "/dev/msdosfs/ESP";
    assert config.virtualisation.vmVariant.virtualisation.useEFIBoot;
    assert !config.virtualisation.vmVariant.virtualisation.netMountNixStore;
    assert !config.virtualisation.vmVariant.virtualisation.netMountBoot;
    assert config.virtualisation.vmVariant.virtualisation.diskImage != null;
      pkgs.runCommand "nixbsd-p53-configuration-check" {} ''
        touch "$out"
      '';

    formatter.x86_64-linux = pkgs.alejandra;
  };
}
