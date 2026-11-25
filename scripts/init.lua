vim.opt.runtimepath:append(vim.uv.cwd())

vim.filetype.add({
	filename = {
		["todo.txt"] = "todotxt",
		["done.txt"] = "todotxt",
	},
})

M = require("todotxt")

local mini = vim.env.MINI_NVIM

if not mini then error("MINI_NVIM is not set. Run this config inside devenv.") end

vim.opt.runtimepath:append(mini)

local grammars_dir = vim.env.TODOTXT_GRAMMARS

if grammars_dir then
	local so = vim.fs.joinpath(grammars_dir, "todotxt.so")
	if vim.uv.fs_stat(so) then pcall(vim.treesitter.language.add, "todotxt", { path = so }) end
end

if #vim.api.nvim_list_uis() == 0 then
	local todo_dir_path = vim.fs.joinpath("/", "tmp", "todotxt.nvim")
	local todo_file_path = vim.fs.joinpath(todo_dir_path, "todo.txt")

	vim.fn.mkdir(todo_dir_path, "p")

	vim.fn.writefile({
		"(A) Test task 1 +project1 @context1 due:2025-12-31",
		"(B) Test task 2 +project2 @context2",
		"(C) Test task 3 +project3 @context3",
		"x 2025-01-01 Test task 4 +project4 @context4",
		"2025-01-01 Test task 5 +project5 @context5",
		"Test task 6",
		"(A) Test task 7",
		"(A)   Multiple spaces   +project   @context",
	}, todo_file_path)

	vim.fn.writefile({}, vim.fs.joinpath(todo_dir_path, "done.txt"))

	M.setup({ todotxt = todo_file_path, donetxt = vim.fs.joinpath(todo_dir_path, "done.txt"), lsp = false })

	require("mini.test").setup()
	require("mini.doc").setup()
else
	require("mini.completion").setup()

	M.setup({})

	vim.g.mapleader = " "
	vim.keymap.set("n", "<F2>", vim.lsp.buf.rename)
	vim.keymap.set("n", "<leader>a", vim.lsp.buf.code_action)
	vim.keymap.set("n", "gq", vim.lsp.buf.format)
	vim.keymap.set("n", "grr", vim.lsp.buf.references)
end
