{ lib, config, ... }:

{
  options = {
    ssh-keys = {
      publicKey = lib.mkOption {
        type = lib.types.str;
        description = "SSH public key to authorize";
      };
      comment = lib.mkOption {
        type = lib.types.str;
        default = "lucy@dotfiles";
        description = "Comment for the SSH key";
      };
    };
  };

  config = {
    users.users.lucy.openssh.authorizedKeys.keys = [
      "${config.ssh-keys.publicKey} ${config.ssh-keys.comment}"
    ];

    users.users.root.openssh.authorizedKeys.keys = [
      "${config.ssh-keys.publicKey} ${config.ssh-keys.comment}"
    ];
  };
}
