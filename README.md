# todotxt.nvim

A lua version of [`todotxt.vim`](https://github.com/freitass/todo.txt-vim).

## Installation

Using [`mini.deps`](https://github.com/echasnovski/mini.deps):

```lua
MiniDeps.now(function()
  MiniDeps.add({ source = "phrmendes/todotxt.nvim" })

  require("todotxt").setup({
    todotxt = vim.env.HOME .. "/Documents/notes/todo.txt",
    donetxt = vim.env.HOME .. "/Documents/notes/done.txt",
    create_commands = true,
  })
end)
```

Using [`lazy.nvim`](https://lazy.folke.io/installation):

```lua
return {
  "phrmendes/todotxt.nvim",
  cmd = { "TodoTxt", "DoneTxt" },
  opts = {
    todotxt = "path/to/the/todo.txt",
    donetxt = "path/to/the/done.txt",
  },
}
```

Suggested keybindings:

```lua
vim.keymap.set("n", "<leader>tn", function() require("todotxt").capture_todo() end, {
  desc = "New entry"
})

vim.keymap.set("n", "<leader>tt", function() require("todotxt").toggle_todotxt() end, {
  desc = "Open"
})

vim.keymap.set("n", "<c-c>n", function() require("todotxt").cycle_priority() end, {
  desc = "todo.txt: cycle priority",
})

vim.keymap.set("n", "<cr>", function() require("todotxt").toggle_todo_state() end, {
  desc = "todo.txt: toggle task state",
})

vim.keymap.set("n", "<leader>td", function() require("todotxt").move_done_tasks() end, {
  desc = "Move to done.txt",
})

vim.keymap.set("n", "<leader>tsd", function() require("todotxt").sort_tasks_by_due_date() end, {
  desc = "By due:date",
})

vim.keymap.set("n", "<leader>tsP", function() require("todotxt").sort_tasks_by_priority() end, {
  desc = "By (priority)",
})

vim.keymap.set("n", "<leader>tsc", function() require("todotxt").sort_tasks_by_context() end, {
  desc = "By @context",
})

vim.keymap.set("n", "<leader>tsp", function() require("todotxt").sort_tasks_by_project() end, {
  desc = "By +project",
})

vim.keymap.set("n", "<leader>tss", function() require("todotxt").sort_tasks() end, {
  desc = "Default"
})
```

This plugin works without dependencies, but for enhanced functionality (like syntax highlighting), the [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter) plugin with the [`todotxt`](https://github.com/arnarg/tree-sitter-todotxt) parser is recommended:

```lua
require("nvim-treesitter.configs").setup({
  ensure_installed = { "todotxt" },
  highlight = { enable = true },
})
```

The default path for `todo.txt` is `~/Documents/todo.txt`. Check the [help file](./doc/todotxt.txt) for more information.

## References

- [`todo.txt`](https://github.com/todotxt/todo.txt)
