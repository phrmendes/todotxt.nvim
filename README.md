# todotxt.nvim

A lua version of the [`todotxt.vim`](https://github.com/freitass/todo.txt-vim) plugin for Neovim.

## Installation

Using [`lazy.nvim`](https://lazy.folke.io/installation):

```lua
return {
  "phrmendes/todotxt.nvim",
  cmd = { "TodoTxt", "DoneTxt" },
  opts = {
    todotxt = "path/to/the/todo.txt",
    donetxt = "path/to/the/done.txt",
  },
  -- suggested keybindings
  keys = {
      { "<leader>t", "", desc = "+todo.txt" },
      { "<leader>ts", "", desc = "+sort", ft = "todotxt" },
      {
        "<c-c>n",
        function() require("todotxt").cycle_priority() end,
        desc = "todo.txt: cycle priority",
        ft = "todotxt",
      },
      {
        "<cr>",
        function() require("todotxt").toggle_todo_state() end,
        desc = "todo.txt: toggle task state",
        ft = "todotxt",
      },
      {
        "<leader>tn",
        function() require("todotxt").capture_todo() end,
        desc = "New entry",
      },
      {
        "<leader>tt",
        function() require("todotxt").toggle_todotxt() end,
        desc = "Open",
      },
      {
        "<leader>td",
        function() require("todotxt").move_done_tasks() end,
        desc = "Move to done.txt",
        ft = "todotxt",
      },
      {
        "<leader>tss",
        function() require("todotxt").sort_tasks() end,
        desc = "Sort",
        ft = "todotxt",
      },
      {
        "<leader>tsd",
        function() require("todotxt").sort_tasks_by_due_date() end,
        desc = "Sort by due:date",
        ft = "todotxt",
      },
      {
        "<leader>tsP",
        function() require("todotxt").sort_tasks_by_priority() end,
        desc = "Sort by (priority)",
        ft = "todotxt",
      },
      {
        "<leader>tsc",
        function() require("todotxt").sort_tasks_by_context() end,
        desc = "Sort by @context",
        ft = "todotxt",
      },
      {
        "<leader>tsp",
        function() require("todotxt").sort_tasks_by_project() end,
        desc = "Sort by +project",
        ft = "todotxt",
      },
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

Check the [help file](./doc/todotxt.txt) for more information.

## References

- [`todo.txt`](https://github.com/todotxt/todo.txt)
