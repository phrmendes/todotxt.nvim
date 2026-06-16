{ pkgs, ... }:

{
  name = "todotxt";

  packages = with pkgs; [ neovim ];

  tasks = {
    test.exec = ''nvim --headless --noplugin -u ./scripts/init.lua -c "lua MiniTest.run()"'';
    doc.exec = ''nvim --headless --noplugin -u ./scripts/init.lua -c "lua require('mini.doc').generate()" -c "qa!"'';
  };
}
