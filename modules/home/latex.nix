{ config, lib, pkgs, ... }:

{
  options.lucy.latex = {
    enable = lib.mkEnableOption "LaTeX configuration";
  };

  config = lib.mkIf config.lucy.latex {
    home.file.".latexmkrc".text = ''
      # LaTeXmk configuration for lucy
      $pdftex_method = 'lualatex';
      $lualatex = 'lualatex -interaction=nonstopmode -halt-on-error -shell-escape %S %O %A';
      $xelatex = 'xelatex -interaction=nonstopmode -halt-on-error -shell-escape %S %O %A';
      $pdflualatex = 'lualatex -interaction=nonstopmode -halt-on-error -shell-escape %S %O %A';
      
      $out_dir = 'build';
      $aux_dir = 'build';
      
      $pdf_mode = 4;
      $dvi_mode = 0;
      $ps_mode = 0;
      
      $pdf_previewer = 'zathura --fork';
      $pdf_update_method = 4;
      $pdf_update_signal = 'SIGHUP';
      
      $view_relates_prefix = 'synctex view -x -i %l -o %b -s %d/%f -d %D';
      
      $minted_auto任 = 1;
      $minted_options任 = '-linenos=true -fontsize=\\small -pythonprinter=pygmentsize=\\number\\fontsize';
      
      $makeindex = 'makeindex %S -s gind.ist -o %D %O %A';
      
      $biber = 'biber %O %A --bblatency=0';
      
      $clean_ext = 'synctex.gz';
      $clean_full_ext = 'aux bbl blg fdb_latexmk glg glo gls ist log nav out snm toc vrb xdy';
      
      $max_print_line = 10000;
      $error_line = 254;
      $half_error_line = 238;
    '';

    home.packages = with pkgs; [
      zathura
    ];

    programs.zathura = {
      enable = true;
      options = {
        zoom-step = 10;
        pages-per-row = 1;
        default-zoom = "fit-width";
        selection-clipboard = "clipboard";
        show-scrollbar = false;
        window-title-basename = true;
        synctex = {
          forward-search = true;
          editor-command = "nvim --remote-silent +%{line} %{input}";
        };
      };
    };
  };
}
