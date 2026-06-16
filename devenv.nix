{ pkgs, ... }:

{
  name = "todotxt-dev";

  packages = [
    pkgs.neovim
  ];

  scripts.test.exec = ''
    nvim --headless --noplugin -u ./scripts/init.lua -c "lua MiniTest.run()"
  '';

  scripts.doc.exec = ''
    nvim --headless --noplugin -u ./scripts/init.lua -c "lua require('mini.doc').generate()" -c "qa!"
  '';
}
