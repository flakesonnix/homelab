{
  meta = {
    description = "Apply gaming performance tuning and low-latency sysctl settings";
    targets = ["host"];
  };

  moduleFlags = {
    lucy.gaming.performance.enable = true;
    lucy.gaming.performance.cpuFreqGovernor = "performance";
    lucy.gaming.performance.disablePowerProfilesDaemon = true;
    lucy.gaming.gamescope.capSysNice = true;
    lucy.gaming.sysctl.enable = true;
    lucy.gaming.sysctl.network.lowLatency = true;
  };
}
