{ ... }:

{
  name = "todotxt";

  tasks = {
    "test:run".exec = ''nvim --headless --noplugin -u ./scripts/init.lua -c "lua MiniTest.run()"'';
    "doc:run".exec =
      ''nvim --headless --noplugin -u ./scripts/init.lua -c "lua require('mini.doc').generate()" -c "qa!"'';
  };
}
