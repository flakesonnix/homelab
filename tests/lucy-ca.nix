{
  pkgs,
  lib,
  self,
}:
let
  ca = pkgs.callPackage ../pkgs/lucy-ca { };
  certificate = "${ca}/${ca.certificateFile}";
  hosts = lib.mapAttrsToList (_: host: host.config) self.nixosConfigurations;
  guests = map (vm: vm.config.config) (
    lib.attrValues self.nixosConfigurations.mireo.config.microvm.vms
  );
  installer =
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [ ../hosts/pxe-desktop ];
    }).config;
  configurations = hosts ++ guests ++ [ installer ];
  trustsCa =
    config:
    config.security.pki.installCACerts
    && lib.elem certificate config.security.pki.certificateFiles
    &&
      toString config.environment.etc."ssl/certs/ca-certificates.crt".source
      == toString config.security.pki.caBundle
    && toString config.environment.etc."ssl/certs/lucy-ca.crt".source == certificate
    && lib.any (package: (package.pname or "") == "lucy-ca") config.environment.systemPackages
    && (
      !config.programs.firefox.enable
      || lib.elem certificate config.programs.firefox.policies.Certificates.Install
    );
  bundles = lib.unique (map (config: toString config.security.pki.caBundle) configurations);
in
assert self.nixosModules ? lucy-ca;
assert self.packages.${pkgs.stdenv.hostPlatform.system}.lucy-ca.drvPath == ca.drvPath;
assert lib.assertMsg (lib.all trustsCa configurations)
  "Every host, microVM and PXE installer must install and trust lucy-ca";
pkgs.runCommand "lucy-ca-check" { nativeBuildInputs = [ pkgs.openssl ]; } ''
  cmp ${../pkgs/lucy-ca/root.crt} ${certificate}
  test "$(find ${ca} -type f | wc -l)" -eq 1
  ! grep -q 'PRIVATE KEY' ${certificate}
  for bundle in ${lib.escapeShellArgs bundles}; do
    test "$(grep -Ec '^-----BEGIN (TRUSTED )?CERTIFICATE-----$' "$bundle")" -gt 1
    openssl verify -no-CApath -no-CAstore -check_ss_sig -CAfile "$bundle" ${certificate}
  done
  echo 'PASS: public CA package and trust bundles for all hosts, microVMs and PXE'
  touch "$out"
''
