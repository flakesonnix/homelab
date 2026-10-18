{
  pkgs,
  lib,
  self,
}: let
  cfg = self.nixosConfigurations.p53.config;
  idle = cfg.systemd.user.services.ewm-idle;
  locker = cfg.systemd.user.services.ewm-lock;
  systemctl = "${cfg.systemd.package}/bin/systemctl";
  lockCommand = "${systemctl} --user start ewm-lock.service";
  checkPlasma = niri: let
    config =
      (self.nixosConfigurations.p53.extendModules {
        modules = [
          ({lib, ...}: {
            lucy.plasma.enable = lib.mkForce true;
            lucy.plasma.displayManager = "sddm";
            programs.niri.enable = lib.mkForce niri;
          })
        ];
      }).config;
    session =
      if niri
      then "niri"
      else "plasma";
  in
    lib.assertMsg (
      config.services.displayManager.sddm.enable
      && !config.services.displayManager.gdm.enable
      && !config.services.greetd.enable
      && config.services.displayManager.defaultSession == session
      && lib.any (p: lib.elem session p.providedSessions) config.services.displayManager.sessionPackages
      && lib.hasInfix "/bin/sddm" config.services.displayManager.generic.execCmd
      && lib.hasSuffix "/bin/ksshaskpass" config.programs.ssh.askPassword
      && lib.all (a: a.assertion) config.assertions
      && builtins.isString config.system.build.toplevel.drvPath
    ) "Plasma/SDDM must select an installed session, with or without Niri";
  drmScript = pkgs.writeText "desktop-drm.sh" (lib.replaceStrings
    ["/dev/dri/by-path/"]
    ["\"$TMPDIR\"/drm/by-path/"]
    cfg.programs.sway.extraSessionCommands);
  lockScript = pkgs.writeText "ewm-lock.sh" locker.script;
  fakeLocker = pkgs.writeShellScript "swaylock-stub" ''
    test "$*" = '--config /dev/null --ready-fd 3'
    if [ "$LOCK_READY" = 1 ]; then
      printf '\n' >&3
      while [ ! -e "$TMPDIR/notified" ]; do sleep 0.01; done
    else
      exec 3>&-
      sleep 0.1
      exit 1
    fi
  '';
  fakeNotify = pkgs.writeShellScript "notify-stub" ''
    test "$*" = --ready
    touch "$TMPDIR/notified"
  '';
  simulatedLock = pkgs.writeText "ewm-lock-simulated.sh" (lib.replaceStrings
    ["${lib.getExe pkgs.swaylock}" "${cfg.systemd.package}/bin/systemd-notify"]
    ["${fakeLocker}" "${fakeNotify}"]
    locker.script);
  upstreamService = builtins.readFile "${self.inputs.ewm}/resources/ewm.service";
in
  assert checkPlasma false;
  assert checkPlasma true;
  assert lib.assertMsg (
    lib.hasInfix "Type=notify" upstreamService
    && lib.hasInfix "BindsTo=graphical-session.target" upstreamService
    && idle.wantedBy == ["ewm.service"]
    && lib.all (unit:
      unit.requisite
      == ["ewm.service"]
      && unit.partOf == ["ewm.service"]
      && unit.after == ["ewm.service"]
      && unit.unitConfig.ConditionEnvironment == ["XDG_CURRENT_DESKTOP=ewm" "WAYLAND_DISPLAY"])
    [idle locker]
    && locker.wantedBy == []
    && locker.serviceConfig.Type == "notify"
    && locker.serviceConfig.NotifyAccess == "all"
    && idle.serviceConfig.ExecStart == "${lib.getExe pkgs.swayidle} -C /dev/null -w timeout 300 '${lockCommand}' before-sleep '${lockCommand}' lock '${lockCommand}'"
    && cfg.security.pam.services ? swaylock
    && cfg.home-manager.users.lucy.services.swayidle.systemdTargets == ["sway-session.target"]
    && cfg.services.displayManager.gdm.enable
    && !cfg.services.displayManager.sddm.enable
  ) "EWM locking must follow its real service lifecycle and leave GNOME/Sway unchanged";
    pkgs.runCommand "desktop-regressions" {
      nativeBuildInputs = [pkgs.shellcheck pkgs.emacs-nox];
    } ''
      shellcheck --shell=bash ${drmScript} ${lockScript}

      timeout 5s env LOCK_READY=1 bash ${simulatedLock}
      test -e "$TMPDIR/notified"
      rm "$TMPDIR/notified"
      if LOCK_READY=0 bash ${simulatedLock}; then
        exit 1
      fi
      test ! -e "$TMPDIR/notified"

      mkdir -p "$TMPDIR/drm/by-path"
      touch "$TMPDIR/drm/intel" "$TMPDIR/drm/nvidia"
      for scenario in both intel nvidia neither; do
        (
          intel="$TMPDIR/drm/by-path/pci-0000:00:02.0-card"
          nvidia="$TMPDIR/drm/by-path/pci-0000:01:00.0-card"
          rm -f "$intel" "$nvidia"
          case "$scenario" in
            both|intel) ln -s ../intel "$intel" ;;
          esac
          case "$scenario" in
            both|nvidia) ln -s ../nvidia "$nvidia" ;;
          esac
          export WLR_DRM_DEVICES=stale
          source ${drmScript}
          case "$scenario" in
            both) test "$WLR_DRM_DEVICES" = "$TMPDIR/drm/intel:$TMPDIR/drm/nvidia" ;;
            intel) test "$WLR_DRM_DEVICES" = "$TMPDIR/drm/intel" ;;
            nvidia) test "$WLR_DRM_DEVICES" = "$TMPDIR/drm/nvidia" ;;
            neither) test -z "''${WLR_DRM_DEVICES+x}" ;;
          esac
        )
      done

      # Load upstream's real keymap and lock function without starting EWM.
      emacs --batch -Q \
        --load ${self.inputs.ewm}/lisp/ewm-input.el \
        --eval ${lib.escapeShellArg ''
        (progn
          (defvar ewm-idle t)
          (with-temp-buffer
            (insert-file-contents "${self.inputs.ewm}/lisp/ewm.el")
            (goto-char (point-min))
            (re-search-forward "^(defun ewm-lock-session ")
            (goto-char (match-beginning 0))
            (eval (read (current-buffer)))))
      ''} \
        ${cfg.programs.ewm.extraEmacsArgs} \
        --eval ${lib.escapeShellArg ''
        (progn
          (require 'cl-lib)
          (unless (and (not ewm-idle)
                       (eq (lookup-key ewm-mode-map (kbd "s-l")) 'ewm-lock-session))
            (error "EWM lock binding or idle ownership is wrong"))
          (cl-letf (((symbol-function 'start-process)
                     (lambda (&rest args)
                        (unless (equal args '("loginctl" nil "loginctl" "lock-session"))
                          (error "Super+L did not request the logind lock handler")))))
            (call-interactively (lookup-key ewm-mode-map (kbd "s-l")))))
      ''}
      touch "$out"
    ''
