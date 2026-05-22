{lib}: {
  lucy = {
    default = lib.fileContents ./keys/lucy.pub;
    git = lib.fileContents ./keys/lucy_git.pub;
    servers = lib.fileContents ./keys/lucy_servers.pub;
  };
}
