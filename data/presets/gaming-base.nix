{
  meta = {
    description = "Enable the shared gaming module baseline";
    targets = ["host"];
  };

  moduleFlags = {
    lucy.gaming.enable = true;
  };
}
