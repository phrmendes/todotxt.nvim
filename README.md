# todotxt.nvim

A lua version of the [`todotxt.vim`](https://github.com/freitass/todo.txt-vim) plugin for Neovim.

## Installation

### Using mini.deps

Installation instructions: [`mini.deps`](https://github.com/echasnovski/mini.deps#installation)

```lua
local add = require("mini.deps").add

add({
    source = "phrmendes/todotxt.nvim",
})
```

## Configuration

You can configure the plugin by calling the `setup` function. The default path for todotxt is `~/Documents/todotxt`.

```lua
local later = require("mini.deps")

later(function()
    require("todotxt").setup({
        todo = "path/to/your/todotxt",
        done = "path/to/your/done",
    })
end)
```

Suggested keybindings:

```lua
local opts = { noremap = true }

opts.desc = "todo.txt: toggle task state"
vim.keymap.set("n", "<c-c><c-x>", require("todotxt").toggle_todo_state, opts)

opts.desc = "todo.txt: cycle priority"
vim.keymap.set("n", "<c-c><c-p>", require("todotxt").cycle_priority, opts)

opts.desc = "Sort"
vim.keymap.set("n", "<leader>ts", require("todotxt").sort_tasks, opts)

opts.desc = "Sort by (priority)"
vim.keymap.set("n", "<leader>tP", require("todotxt").sort_tasks_by_priority, opts)

opts.desc = "Sort by @context"
vim.keymap.set("n", "<leader>tc", require("todotxt").sort_tasks_by_context, opts)

opts.desc = "Sort by +project"
vim.keymap.set("n", "<leader>tp", require("todotxt").sort_tasks_by_project, opts)

opts.desc = "Sort by due:date"
vim.keymap.set("n", "<leader>tD", require("todotxt").sort_tasks_by_due_date, opts)

opts.desc = "Move to done.txt"
vim.keymap.set("n", "<leader>td", require("todotxt").move_done_tasks, opts)
```

## Usage

Check the [help file](./doc/todotxt.txt) for more information.

## References

- [`todo.txt`](https://github.com/todotxt/todo.txt)
- [`mini.test`](https://github.com/echasnovski/mini.test)
- [`mini.test` example](https://github.com/echasnovski/mini.nvim/blob/main/TESTING.md)
