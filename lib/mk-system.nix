{
  lib,
  nixpkgs,
  deploy-rs,
  system,
  inputs,
  hostName,
  domain,
}:

let
  filterNixFiles = k: v: v == "regular" && lib.hasSuffix ".nix" k;

  importNixFiles =
    path:
    lib.forEach (lib.mapAttrsToList (name: _: path + ("/" + name)) (
      lib.filterAttrs filterNixFiles (builtins.readDir path)
    )) import;
in
{
  mkSys =
    sshHost: extraModules: name: domain: user:
    let
      deployUser = if user == null then "root" else user;
    in
    {
      conf = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs domain; };
        modules = [
          (./hosts + "/${name}/default.nix")
        ]
        ++ (importNixFiles (./modules/by-host + "/${name}"))
        ++ extraModules;
      };

      deploy = {
        hostname = sshHost;
        profiles.system = {
          user = deployUser;
          path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${name};
        };
      };
    };

  inherit filterNixFiles importNixFiles;
}
