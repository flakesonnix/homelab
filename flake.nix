{
  description = "HomeLab NixOS configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
  };

  outputs =
    {
      self,
      nixpkgs,
      deploy-rs,
    }@inputs:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs { inherit system; };

      mkSystem = import ./lib/mk-system.nix {
        inherit
          nixpkgs
          deploy-rs
          system
          inputs
          ;
        lib = nixpkgs.lib;
      };

      mkIso = import ./lib/mk-iso.nix {
        inherit
          nixpkgs
          system
          self
          ;
        lib = nixpkgs.lib;
      };

      mkSys = mkSystem.mkSys;

      hosts = { };

    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nixos-rebuild-ng
          deploy-rs.packages.${system}.deploy-rs
          nil
          nixfmt-rfc-style
        ];
      };

      nixosConfigurations = builtins.mapAttrs (_: host: host.conf) hosts;

      deploy.nodes = builtins.mapAttrs (_: host: host.deploy) hosts;

      iso = mkIso.mkCalamaresIso "installer" [ ./hosts/iso ];

      packages.x86_64-linux.iso = mkIso.mkCalamaresIso "installer" [ ./hosts/iso ];
    };
}
