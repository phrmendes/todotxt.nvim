# todotxt.nvim

A lua version of the [`todotxt.vim`](https://github.com/freitass/todo.txt-vim) plugin for Neovim.

## Installation

Using [`mini.deps`](https://github.com/echasnovski/mini.deps#installation):

```lua
local add = require("mini.deps").add
local later = require("mini.deps")

add({
    source = "phrmendes/todotxt.nvim",
    depends = { "nvim-treesitter/nvim-treesitter" },
})

later(function()
    require("todotxt").setup({
        todotxt = "path/to/your/todotxt",
        donetxt = "path/to/your/done",
    })
end)
```

Using [`lazy.nvim`](https://lazy.folke.io/installation):

```lua
return {
    "phrmendes/todotxt.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
        require("todotxt").setup({
            todotxt = "/path/to/my/todo.txt",
            donetxt = "/path/to/my/done.txt",
        })
    end
}
```

This plugin requires the `nvim-treesitter` plugin to work properly. You must install the [`todotxt`](https://github.com/arnarg/tree-sitter-todotxt) parser for `nvim-treesitter`:

```lua
require("nvim-treesitter.conigs").setup({
    ensure_installed = { "todotxt" },
    highlight = { enable = true },
})
```

The default path for `todo.txt` is `~/Documents/todo.txt`.

Suggested keybindings:

```lua
local opts = { noremap = true }

opts.desc = "todo.txt: toggle task state"
vim.keymap.set("n", "<c-c><c-x>", require("todotxt").toggle_todo_state, opts)

opts.desc = "todo.txt: cycle priority"
vim.keymap.set("n", "<c-c><c-p>", require("todotxt").cycle_priority, opts)

opts.desc = "Open"
vim.keymap.set("n", "<leader>tt", require("todotxt").open_todo_file, opts)

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
