# todotxt.nvim

A lua version of [`todotxt.vim`](https://github.com/freitass/todo.txt-vim) with enhanced functionality for managing todo.txt files in Neovim.

## Features

- **File Management**: Toggle between todo.txt and done.txt files in floating windows
- **Task Operations**: Mark tasks as complete/incomplete, cycle task priorities (A-C)
- **New Task Creation**: Quick task capture with automatic date formatting
- **Task Organization**: Multiple sorting options (priority, context, project, due date)
- **Task Movement**: Automatically move completed tasks to done.txt file
- **Ghost Text**: Visual priority hints with customizable mappings and toggle support
- **Treesitter Support**: Enhanced syntax highlighting with todotxt parser

## Installation

Using [`mini.deps`](https://github.com/echasnovski/mini.deps) and `vim.pack`:

```lua
MiniDeps.now(function()
  vim.pack.add({ "https://github.com/phrmendes/todotxt.nvim" })

  require("todotxt").setup({
    todotxt = vim.env.HOME .. "/Documents/notes/todo.txt",
    donetxt = vim.env.HOME .. "/Documents/notes/done.txt",
    ghost_text = {
      enable = true,
      mappings = {
        ["(A)"] = "now",
        ["(B)"] = "next",
        ["(C)"] = "today",
      },
    },
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
    ghost_text = {
      enable = true,
      mappings = {
        ["(A)"] = "now",
        ["(B)"] = "next",
        ["(C)"] = "today",
      },
    },
  },
}
```

Add these options:

```lua
vim.filetype.add({
  filename = {
    ["todo.txt"] = "todotxt",
    ["done.txt"] = "todotxt",
  },
})
```

Suggested keybindings:

```lua
vim.keymap.set("n", "<leader>tn", "<cmd>TodoTxt new<cr>", { desc = "New todo entry" })
vim.keymap.set("n", "<leader>tt", "<cmd>TodoTxt<cr>", { desc = "Toggle todo.txt" })
vim.keymap.set("n", "<leader>td", "<cmd>DoneTxt<cr>", { desc = "Toggle done.txt" })
vim.keymap.set("n", "<leader>tg", "<cmd>TodoTxt ghost<cr>", { desc = "Toggle ghost text" })
vim.keymap.set("n", "<cr>", "<Plug>(TodoTxtToggleState)", { desc = "Toggle task state" })
vim.keymap.set("n", "<c-c>n", "<Plug>(TodoTxtCyclePriority)", { desc = "Cycle priority" })
vim.keymap.set("n", "<leader>tm", "<Plug>(TodoTxtMoveDone)", { desc = "Move done tasks" })
vim.keymap.set("n", "<leader>tss", "<Plug>(TodoTxtSortTasks)", { desc = "Sort tasks (default)" })
vim.keymap.set("n", "<leader>tsp", "<Plug>(TodoTxtSortByPriority)", { desc = "Sort by priority" })
vim.keymap.set("n", "<leader>tsc", "<Plug>(TodoTxtSortByContext)", { desc = "Sort by context" })
vim.keymap.set("n", "<leader>tsP", "<Plug>(TodoTxtSortByProject)", { desc = "Sort by project" })
vim.keymap.set("n", "<leader>tsd", "<Plug>(TodoTxtSortByDueDate)", { desc = "Sort by due date" })
```

This plugin works without dependencies, but for enhanced functionality (like syntax highlighting), the [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter) plugin with the [`todotxt`](https://github.com/arnarg/tree-sitter-todotxt) parser is recommended:

```lua
vim.pack.add({ src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main"})

require("nvim-treesitter").install({ "todotxt" })
```

The default path for `todo.txt` is `~/Documents/todo.txt`. Check the [help file](./doc/todotxt.txt) for more information.

## Ghost Text Feature

The ghost text feature displays visual hints next to tasks based on their priority levels. This can be customized with your own mappings:

```lua
ghost_text = {
  enable = true,
  mappings = {
    ["(A)"] = "now",      -- High priority tasks
    ["(B)"] = "next",     -- Medium priority tasks
    ["(C)"] = "today",    -- Lower priority tasks
    ["(D)"] = "tomorrow", -- Even lower priority
    ["(E)"] = "this week",
    ["(F)"] = "next week",
  },
  prefix = " ",           -- Text prefix
  highlight = "Comment",  -- Highlight group
}
```

You can toggle ghost text on/off using `:TodoTxt ghost` or the suggested keybinding.

## Commands

- `:TodoTxt` - Toggle todo.txt file in floating window
- `:TodoTxt new` - Create a new todo entry
- `:TodoTxt ghost` - Toggle ghost text display
- `:DoneTxt` - Toggle done.txt file in floating window

## References

- [`todo.txt`](https://github.com/todotxt/todo.txt)
