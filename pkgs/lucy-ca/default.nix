{
  lib,
  runCommand,
  openssl,
}:
let
  certificateFile = "share/ca-certificates/lucy-ca.crt";
  sha256Fingerprint = "de8a1c7b92633abf93b0e242a01f083812cf8241f6ac75c9b4e124fbde66564d";
in
runCommand "lucy-ca-2026.10.18"
  {
    pname = "lucy-ca";
    version = "2026.10.18";
    nativeBuildInputs = [ openssl ];
    passthru = { inherit certificateFile sha256Fingerprint; };
    meta = {
      description = "Public root certificate for Lucy's homelab CA";
      platforms = lib.platforms.all;
    };
  }
  ''
    certificate=${./root.crt}
    test "$(grep -c '^-----BEGIN CERTIFICATE-----$' "$certificate")" -eq 1
    ! grep -q 'PRIVATE KEY' "$certificate"
    openssl x509 -in "$certificate" -noout -ext basicConstraints | grep -q 'CA:TRUE'
    openssl verify -check_ss_sig -CAfile "$certificate" "$certificate"
    fingerprint=$(openssl x509 -in "$certificate" -outform DER | sha256sum | cut -d' ' -f1)
    test "$fingerprint" = '${sha256Fingerprint}'

    install -Dm444 "$certificate" "$out/${certificateFile}"
  ''
