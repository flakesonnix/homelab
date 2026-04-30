{
  services.asteriskLocal = {
    enable = false;
    openFirewall = true;
    phones = {
      desk1 = {
        extension = "1001";
        password = "secret123";
      };
      desk2 = {
        extension = "1002";
        password = "secret456";
      };
    };
    extraExtensions = ''
      exten => 9000,1,Dial(PJSIP/desk1&PJSIP/desk2,20)
      same => n,Hangup()
    '';
  };

  hq.audio.streamTo = "192.168.178.2";

  programs.noisetorch.enable = true;
}
