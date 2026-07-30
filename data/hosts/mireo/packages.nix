{pkgs, ...}: {
  systemPackages = with pkgs; [
    # Network diagnostics
    ethtool
    iperf3
    mtr
    netcat-gnu
    nmap
    socat
    tcpdump

    # System analysis
    btop
    dmidecode
    file
    htop
    jq
    lm_sensors
    lsof
    ncdu
    pciutils
    smartmontools
    strace
    sysstat
    usbutils
  ];
}
