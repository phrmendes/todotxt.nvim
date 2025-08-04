default: test

@test:
    nvim --headless --noplugin -u ./scripts/init.lua -c "lua MiniTest.run()"

@test_file file:
    nvim --headless --noplugin -u ./scripts/init.lua -c "lua MiniTest.run_file('{{file}}')"
