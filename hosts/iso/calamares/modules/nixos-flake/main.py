#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import libcalamares
import subprocess
import os

import gettext

_ = gettext.translation(
    "calamares-python",
    localedir=libcalamares.utils.gettext_path(),
    languages=libcalamares.utils.gettext_languages(),
    fallback=True,
).gettext

status = _("Installing NixOS from flake")


def pretty_name():
    return _("Installing NixOS from flake")


def pretty_status_message():
    return status


def run():
    global status
    gs = libcalamares.globalstorage

    root_mount_point = gs.value("rootMountPoint")
    hostname = gs.value("hostname") or "nixos"

    flake_url = libcalamares.job.configuration.get(
        "flake-url", "github:yourusername/homelab"
    )
    flake_host = libcalamares.job.configuration.get("flake-host", hostname)

    status = _("Generating hardware configuration")
    libcalamares.job.setprogress(0.1)

    try:
        subprocess.check_output(
            ["pkexec", "nixos-generate-config", "--root", root_mount_point],
            stderr=subprocess.STDOUT,
        )
    except subprocess.CalledProcessError as e:
        if e.output is not None:
            libcalamares.utils.error(e.output.decode("utf8"))
        return (_("nixos-generate-config failed"), _(e.output.decode("utf8")))

    status = _("Installing NixOS from flake: {}#{}").format(flake_url, flake_host)
    libcalamares.job.setprogress(0.2)

    nixos_install_cmd = [
        "pkexec",
        "nixos-install",
        "--flake",
        f"{flake_url}#{flake_host}",
        "--no-root-passwd",
        "--root",
        root_mount_point,
    ]

    try:
        output = ""
        proc = subprocess.Popen(
            nixos_install_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        while True:
            line = proc.stdout.readline().decode("utf-8")
            output += line
            libcalamares.utils.debug("nixos-install: {}".format(line.strip()))
            if not line:
                break
        exit_code = proc.wait()
        if exit_code != 0:
            return (_("nixos-install failed"), _(output))
    except Exception as e:
        return (_("nixos-install failed"), str(e))

    status = _("Installation complete")
    libcalamares.job.setprogress(1.0)

    return None
