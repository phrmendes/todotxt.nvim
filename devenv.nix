{ pkgs, ... }:

let
  grammars = pkgs.tree-sitter.withPlugins (p: [ p.tree-sitter-todotxt ]);
in
{
  languages.lua = {
    enable = true;
    package = pkgs.luajit;
    lsp.package = pkgs.lua-language-server;
  };

  packages = with pkgs; [
    commitizen
    git
    neovim
    nushell
    nufmt
    nu-lint
    stylua
  ];

  env = {
    MINI_NVIM = "${pkgs.vimPlugins.mini-nvim}";
    TODOTXT_GRAMMARS = grammars;
  };

  enterTest = "nu scripts/test.nu";

  git-hooks.hooks = {
    stylua.enable = true;
    nufmt.enable = true;
    nu-lint.enable = true;
    commitizen = {
      enable = true;
      name = "commitizen";
      entry = "${pkgs.commitizen}/bin/cz check --commit-msg-file";
      language = "system";
      stages = [ "commit-msg" ];
    };
    docs = {
      enable = true;
      name = "docs";
      entry = "${pkgs.coreutils}/bin/env MINI_NVIM=${pkgs.vimPlugins.mini-nvim} TODOTXT_GRAMMARS=${grammars} ${pkgs.neovim}/bin/nvim --headless --noplugin -u ./scripts/init.lua -c 'lua MiniDoc.generate(nil, \"doc/todotxt.txt\")' -c 'qa!'";
      files = "^lua/";
      pass_filenames = false;
      language = "system";
    };
  };
}
