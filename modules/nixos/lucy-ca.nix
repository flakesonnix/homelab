{
  config,
  lib,
  pkgs,
  ...
}:
let
  ca = pkgs.callPackage ../../pkgs/lucy-ca { };
  certificate = "${ca}/${ca.certificateFile}";
in
{
  environment.systemPackages = [ ca ];
  environment.etc."ssl/certs/lucy-ca.crt".source = certificate;
  security.pki.certificateFiles = [ certificate ];

  # Firefox's system-wide policy takes precedence over package policies.
  # Explicit installation works on Linux without ImportEnterpriseRoots.
  programs.firefox.policies.Certificates.Install = lib.mkIf config.programs.firefox.enable [
    certificate
  ];
}
