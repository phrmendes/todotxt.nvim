default: test

@mini:
    mkdir -p deps
    git clone --filter=blob:none https://github.com/echasnovski/mini.nvim deps/mini.nvim

@test:
    nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

@test_file file:
    nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('{{file}}')"
