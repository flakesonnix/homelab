{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.programs.bat.enable {
    programs.bat = {
      config = {
        style = "numbers,changes,header,grid";
        tabs = "2";
        pager = "less -FR";
      };
    };
  };
}
