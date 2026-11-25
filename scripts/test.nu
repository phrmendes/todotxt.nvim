# Run the todotxt test suite.
def main []: nothing -> nothing {
    let root = $env.CURRENT_FILE | path dirname | path dirname
    cd $root
    nvim --headless --noplugin -u ($root | path join scripts/init.lua) -c 'lua MiniTest.run()' -c 'qa!'
}
