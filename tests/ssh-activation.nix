{
  pkgs,
  lib,
  self,
}: let
  home = self.nixosConfigurations.p53.config.home-manager.users.lucy;
  activation = home.home.activation.fixSshConfigPermissions;
  script = pkgs.writeText "fix-ssh-config.sh" activation.data;
in
  assert home.home.file.".ssh/config".force;
  assert activation.after == ["linkGeneration"];
    pkgs.runCommand "ssh-activation" {
      nativeBuildInputs = [pkgs.openssh];
    } ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME/.ssh"
      run() { "$@"; }

      for host in first second; do
        printf 'Host fixture\n  HostName %s.example\n' "$host" > "$TMPDIR/config-$host"
        chmod 444 "$TMPDIR/config-$host"
        # Home Manager force-relinks this managed file before the hook runs.
        rm -f "$HOME/.ssh/config"
        ln -s "$TMPDIR/config-$host" "$HOME/.ssh/config"
        source ${script}
        test ! -L "$HOME/.ssh/config"
        test "$(stat -c %a "$HOME/.ssh/config")" = 600
        test "$(stat -c %a "$HOME/.ssh")" = 700
        cmp "$HOME/.ssh/config" "$TMPDIR/config-$host"
        ssh -G -F "$HOME/.ssh/config" fixture | grep -Fx "hostname $host.example"
      done

      source ${script}
      test ! -e "$HOME/.ssh/config.tmp"
      touch "$out"
    ''
