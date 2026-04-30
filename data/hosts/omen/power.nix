{
  lucy.serialGetty.disabled = ["ttyS0" "ttyS1" "ttyS2" "ttyS3"];

  lucy.nvidia.resumeWorkaround = {
    enable = true;
    restartUnits = ["greetd.service"];
  };

  services.thermald.enable = true;

  powerManagement.enable = true;
}
