{
  config,
  pkgs,
  lib,
  ...
}: let
  bashPrompt = ''
    __lucy_git_branch() {
      local branch
      branch=$(git branch --show-current 2>/dev/null) || return
      [ -n "$branch" ] && printf ' [%s]' "$branch"
    }

    __lucy_prompt() {
      local exit_code=$?
      local reset='\[\e[0m\]'
      local pink='\[\e[38;5;213m\]'
      local purple='\[\e[38;5;177m\]'
      local blue='\[\e[38;5;111m\]'
      local red='\[\e[38;5;203m\]'
      local status=""

      if [ "$exit_code" -ne 0 ]; then
        status=" ''${red}[$exit_code]"
      fi

      PS1="''${pink}┌─[''${purple}\u@\h''${pink}]─[''${blue}\w''${pink}]$(__lucy_git_branch)$status''${reset}\n''${pink}└─❯ ''${reset}"
    }

    PROMPT_COMMAND=__lucy_prompt
  '';
in {
  options.lucy.shell = {
    enable = lib.mkEnableOption "lucy's shell configuration";
  };

  config = lib.mkIf config.lucy.shell.enable {
    programs.bash = {
      enable = true;
      enableCompletion = true;
      historyControl = ["ignoreboth" "erasedups"];
      historyFileSize = 50000;
      historySize = 10000;
      shellAliases = {
        neofetch = "hyfetch";
        ls = "ls --color=auto -F";
        ll = "ls -lah";
        la = "ls -A";
        grep = "grep --color=auto";
        rebuild = "sudo nixos-rebuild switch --flake ~/Documents/dotfiles#omen";
        uds = "df -h";
        umc = "free -m";
        specs = "hyfetch";
      };
      initExtra = ''
        shopt -s autocd checkwinsize cmdhist globstar histappend
        bind 'set completion-ignore-case on'
        bind 'set show-all-if-ambiguous on'
        alias neofetch=hyfetch
        ${bashPrompt}
      '';
    };

    programs.zsh.enable = lib.mkDefault false;

    home.sessionVariables = {
      SHELL = "${pkgs.bashInteractive}/bin/bash";
    };
  };
}
