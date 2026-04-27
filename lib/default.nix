{
  mkUser = {
    username,
    description ? "",
    modules ? [],
  }: {
    inherit username modules description;
  };
}
