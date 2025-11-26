vim.opt.runtimepath:append(vim.uv.cwd())

if #vim.api.nvim_list_uis() == 0 then
	local packages_path = "deps"
	local mini_path = vim.fs.joinpath(packages_path, "pack", "deps", "start", "mini.nvim")
	local todo_dir_path = vim.fs.joinpath("/", "tmp", "todotxt.nvim")
	local todo_file_path = vim.fs.joinpath(todo_dir_path, "todo.txt")
	local done_file_path = vim.fs.joinpath(todo_dir_path, "done.txt")

	if not vim.uv.fs_stat(mini_path) then
		local mini_repo = "https://github.com/echasnovski/mini.nvim"
		local out = vim.system({ "git", "clone", "--filter=blob:none", mini_repo, mini_path }):wait()

		if out.code ~= 0 then os.exit(1) end
	else
		local out = vim.system({ "git", "-C", mini_path, "pull" }):wait()
		if out.code ~= 0 then os.exit(1) end
	end

	vim.filetype.add({
		filename = {
			["todo.txt"] = "todotxt",
			["done.txt"] = "todotxt",
		},
	})

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

	vim.fn.writefile({}, done_file_path)

	M = require("todotxt")

	M.setup({ todotxt = todo_file_path, donetxt = done_file_path })

	require("mini.deps").setup({ path = { package = packages_path } })
	require("mini.test").setup()
	require("mini.doc").setup()
end
