{ config, lib, ... }:

{
  options.lucy.bat = {
    enable = lib.mkEnableOption "bat configuration";
  };

  config = lib.mkIf config.lucy.bat.enable {
    programs.bat = {
      enable = true;
      config = {
        style = "numbers,changes,header,grid";
        tabs = "2";
        pager = "less -FR";
      };
    };
  };
}
