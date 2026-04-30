_: {
  services.asteriskLocal = {
    enable = false;
    openFirewall = true;
    phones = {
      desk1 = {
        extension = "1001";
        passwordSopsKey = "asterisk-desk1-password";
      };
      desk2 = {
        extension = "1002";
        passwordSopsKey = "asterisk-desk2-password";
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
