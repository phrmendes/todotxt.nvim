default: test

@test:
    timeout 30 nvim --headless --clean -u scripts/minimal_init.lua +"lua MiniTest.run()" +qa!

@test_file file:
    timeout 30 nvim --headless --clean -u scripts/minimal_init.lua +"lua MiniTest.run_file('{{file}}')" +qa!
