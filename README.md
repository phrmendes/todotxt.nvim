# todotxt.nvim

A lua version of the [`todotxt.vim`](https://github.com/freitass/todo.txt-vim) plugin for Neovim.

## Installation

Using [`lazy.nvim`](https://lazy.folke.io/installation):

```lua
return {
  "phrmendes/todotxt.nvim",
  opts = {
    todotxt = "path/to/the/todo.txt",
    donetxt = "path/to/the/done.txt",
  },
}
```

This plugin works without dependencies, but for enhanced functionality (like syntax highlighting), the [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter) plugin with the [`todotxt`](https://github.com/arnarg/tree-sitter-todotxt) parser is recommended:

```lua
require("nvim-treesitter.configs").setup({
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
