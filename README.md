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
- **In-process LSP**: Completion, formatting, code actions, references, and rename

## Installation

Using [`vim.pack`](https://github.com/folke/zen-mode.nvim):

```lua
vim.pack.add({ "https://github.com/phrmendes/todotxt.nvim" })
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

For enhanced functionality (like syntax highlighting), the [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter) plugin with the [`todotxt`](https://github.com/arnarg/tree-sitter-todotxt) parser is recommended:

```lua
vim.pack.add({ src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main"})

require("nvim-treesitter").install({ "todotxt" })
```

## Setup

```lua
require("todotxt").setup({
  todotxt = vim.env.HOME .. "/Documents/notes/todo.txt",
  donetxt = vim.env.HOME .. "/Documents/notes/done.txt",
  max_priority = "C",
  metadata = {
    tag = { sort = "asc" },
    due = { sort = "asc" },
  },
  ghost_text = {
    enable = true,
    mappings = {
      ["(A)"] = "today",
      ["(B)"] = "tomorrow",
      ["(C)"] = "this week",
    },
  },
})
```

## Keybindings

Suggested keybindings:

```lua
vim.keymap.set("n", "<leader>tn", "<cmd>TodoTxt new<cr>", { desc = "New todo entry" })
vim.keymap.set("n", "<leader>tt", "<cmd>TodoTxt<cr>", { desc = "Toggle todo.txt" })
vim.keymap.set("n", "<leader>td", "<cmd>DoneTxt<cr>", { desc = "Toggle done.txt" })
vim.keymap.set("n", "<leader>tg", "<cmd>TodoTxt ghost<cr>", { desc = "Toggle ghost text" })
```

Sort, toggle done, cycle priority, and move done are available as LSP code
actions (`<leader>a`).

The default path for `todo.txt` is `~/Documents/notes/todo.txt`. Check the [help file](./doc/todotxt.txt) for more information.

## LSP

An in-process LSP server starts automatically when opening a `todotxt` buffer. Disable it with `lsp = false` in setup:

```lua
require("todotxt").setup({ lsp = false })
```

### Completion

Trigger characters restrict suggestions by category:

| Trigger               | Shows                          |
| --------------------- | ------------------------------ |
| `(`                   | Priorities `(A)`, `(B)`, `(C)` |
| `+`                   | Projects `+myproject`          |
| `@`                   | Contexts `@home`               |
| Manual (`<C-x><C-o>`) | All categories + `key:` values |

The trigger character is replaced when a suggestion is accepted (prevents doubled
prefixes).

### Formatting

`vim.lsp.buf.format()` rewrites each line to canonical form:

```
x (A) 2025-06-15 2025-01-01 desc due:2025-06-01 @ctx +proj
```

Order: completion marker, priority, completion date, creation date, description,
key:value pairs, contexts, projects.

### Code Actions

Available via `vim.lsp.buf.code_action()`:

- **Toggle done** — mark/unmark task as completed
- **Cycle priority** — advance to next priority letter
- **Sort tasks** — default sort (priority, then alphabetical)
- **Sort by priority / project / context / due date**

### References

Find all occurrences of a `+project` or `@context` tag in the buffer.

### Rename

Rename a `+project` or `@context` across every occurrence in the buffer.

## Ghost Text Feature

The ghost text feature displays visual hints next to tasks based on their priority levels. This can be customized with your own mappings:

```lua
ghost_text = {
  enable = true,
  mappings = {
    ["(A)"] = "today",
    ["(B)"] = "tomorrow",
    ["(C)"] = "this week",
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
