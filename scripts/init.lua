-- Use the new minimal_init.lua for test setup
dofile('scripts/minimal_init.lua')

-- Only set up test data when in headless mode
if #vim.api.nvim_list_uis() == 0 then
	local todo_dir_path = vim.fs.joinpath("/", "tmp", "todotxt.nvim")
	local todo_file_path = vim.fs.joinpath(todo_dir_path, "todo.txt")
	local done_file_path = vim.fs.joinpath(todo_dir_path, "done.txt")

	-- Set up filetype detection
	vim.filetype.add({
		filename = {
			["todo.txt"] = "todotxt",
			["done.txt"] = "todotxt",
		},
	})

	-- Create test directory and files
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

	-- Set up the plugin with test data
	M = require("todotxt")
	M.setup({ todotxt = todo_file_path, donetxt = done_file_path })
end
