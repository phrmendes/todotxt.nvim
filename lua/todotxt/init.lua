---
--- A lua version of the [`todotxt.vim`](https://github.com/freitass/todo.txt-vim) plugin for Neovim.
---
--- MIT License Copyright (c) 2024 Pedro Mendes
---
--- ==============================================================================
--- @module 'todotxt'
local todotxt = {}
local config = {}

--- Setup configuration for the todotxt module.
--- @class Setup
--- @field todotxt string: Path to the todo.txt file
--- @field donetxt string: Path to the done.txt file
--- @field create_commands boolean: Whether to create commands for the functions

--- Updates the buffer if it is open.
--- @param file_path string
--- @param lines string[]
--- @return nil
local update_buffer_if_open = function(file_path, lines)
	local current_buf = vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(current_buf)

	if bufname == file_path then vim.api.nvim_buf_set_lines(0, 0, -1, false, lines) end
end

--- Sorts the tasks in the open buffer by a given function.
--- @param sort_func function: A function that sorts the lines
--- @return nil
local sort_table = function(sort_func)
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	table.sort(lines, sort_func)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

--- Sorts two tasks by its comletion status
--- @param a string: A task
--- @param b string: Another task
--- @return boolean | nil
local sort_by_completion = function(a, b)
	local a_completed = a:match("^x ") ~= nil
	local b_completed = b:match("^x ") ~= nil

	if a_completed ~= b_completed then return not a_completed end

	return nil
end

--- Toggles the todo state of the current line in a todo.txt file.
--- If the line starts with "x YYYY-MM-DD ", it removes it to mark as not done.
--- Otherwise, it adds "x YYYY-MM-DD " at the beginning to mark as done.
--- @return nil
todotxt.toggle_todo_state = function()
	local start_row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, false)[1]
	local pattern = "^x %d%d%d%d%-%d%d%-%d%d "

	if line:match(pattern) then
		line = line:gsub(pattern, "")
	else
		local date = os.date("%Y-%m-%d")
		line = "x " .. date .. " " .. line
	end

	vim.api.nvim_buf_set_lines(0, start_row, start_row + 1, false, { line })
end

--- Opens the todo.txt file in a new split.
--- @return nil
todotxt.open_todo_file = function() vim.cmd("split " .. config.todotxt) end

--- Opens the done.txt file in a new split.
--- @return nil
todotxt.open_done_file = function() vim.cmd("split " .. config.donetxt) end

--- Sorts the tasks in the open buffer by completion status, priority, and text.
--- Follows the standard todo.txt sorting order:
---  1. Incomplete tasks before completed ones
---  2. Tasks sorted by priority (A-Z)
---  3. Tasks with same priority/completion sorted alphabetically
--- @return nil
todotxt.sort_tasks = function()
	sort_table(function(a, b)
		local completion_result = sort_by_completion(a, b)
		if completion_result ~= nil then return completion_result end

		local priority_a = a:match("^%((%a)%)") or "Z"
		local priority_b = b:match("^%((%a)%)") or "Z"

		if priority_a ~= priority_b then return priority_a < priority_b end

		local text_a = a:gsub("^x %S+%s+", ""):gsub("^%(%a%)%s+", ""):gsub("^%d%d%d%d%-%d%d%-%d%d%s+", "")
		local text_b = b:gsub("^x %S+%s+", ""):gsub("^%(%a%)%s+", ""):gsub("^%d%d%d%d%-%d%d%-%d%d%s+", "")

		return text_a < text_b
	end)
end

--- Sorts the tasks in the open buffer by priority.
--- @return nil
todotxt.sort_tasks_by_priority = function()
	sort_table(function(a, b)
		local completion_result = sort_by_completion(a, b)
		if completion_result ~= nil then return completion_result end

		local priority_a = a:match("^%((%a)%)") or "Z"
		local priority_b = b:match("^%((%a)%)") or "Z"
		return priority_a < priority_b
	end)
end

--- Sorts the tasks in the open buffer by project.
--- @return nil
todotxt.sort_tasks_by_project = function()
	sort_table(function(a, b)
		local completion_result = sort_by_completion(a, b)
		if completion_result ~= nil then return completion_result end

		local project_a = a:match("%+%w+") or ""
		local project_b = b:match("%+%w+") or ""
		return project_a < project_b
	end)
end

--- Sorts the tasks in the open buffer by context.
--- @return nil
todotxt.sort_tasks_by_context = function()
	sort_table(function(a, b)
		local completion_result = sort_by_completion(a, b)
		if completion_result ~= nil then return completion_result end

		local context_a = a:match("@%w+") or ""
		local context_b = b:match("@%w+") or ""
		return context_a < context_b
	end)
end

--- Sorts the tasks in the open buffer by due date.
--- @returns boolean
todotxt.sort_tasks_by_due_date = function()
	sort_table(function(a, b)
		local completion_result = sort_by_completion(a, b)
		if completion_result ~= nil then return completion_result end

		local due_date_a = a:match("due:(%d%d%d%d%-%d%d%-%d%d)")
		local due_date_b = b:match("due:(%d%d%d%d%-%d%d%-%d%d)")
		if due_date_a and due_date_b then
			return due_date_a < due_date_b
		elseif due_date_a then
			return true
		elseif due_date_b then
			return false
		else
			return a < b
		end
	end)
end

--- Cycles the priority of the current task between A, B, C, and no priority.
--- @return nil
todotxt.cycle_priority = function()
	local start_row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, false)[1]

	local current_priority = line:match("^%((%a)%)")
	local new_priority

	if current_priority == "A" then
		new_priority = "(B) "
	elseif current_priority == "B" then
		new_priority = "(C) "
	elseif current_priority == "C" then
		new_priority = ""
	else
		new_priority = "(A) "
	end

	if current_priority then
		line = line:gsub("^%(%a%)%s*", new_priority)
	else
		line = new_priority .. line
	end

	vim.api.nvim_buf_set_lines(0, start_row, start_row + 1, false, { line })
end

--- Captures a new todo entry with the current date.
--- @return nil
todotxt.capture_todo = function()
	vim.ui.input({ prompt = "New Todo: " }, function(input)
		if input then
			local date = os.date("%Y-%m-%d")
			local new_todo = date .. " " .. input
			local bufname = vim.api.nvim_buf_get_name(0)

			if bufname == config.todotxt then
				local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
				table.insert(lines, new_todo)
				vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
				return
			end

			local lines = vim.fn.readfile(config.todotxt)
			table.insert(lines, new_todo)
			vim.fn.writefile(lines, config.todotxt)
		end
	end)
end

--- Moves all done tasks from the todo.txt file to the done.txt file.
--- @return nil
todotxt.move_done_tasks = function()
	local todo_lines = vim.fn.readfile(config.todotxt)
	local done_lines = vim.fn.readfile(config.donetxt)
	local remaining_todo_lines = {}

	vim.iter(todo_lines):each(function(line)
		if line:match("^x ") then
			table.insert(done_lines, line)
		else
			table.insert(remaining_todo_lines, line)
		end
	end)

	vim.fn.writefile(remaining_todo_lines, config.todotxt)
	vim.fn.writefile(done_lines, config.donetxt)

	update_buffer_if_open(config.todotxt, remaining_todo_lines)
end

--- Setup function
--- @param opts Setup
todotxt.setup = function(opts)
	opts = opts or {}
	config.todotxt = opts.todotxt or vim.env.HOME .. "/Documents/todo.txt"
	config.donetxt = opts.donetxt or vim.env.HOME .. "/Documents/done.txt"
	config.create_commands = opts.create_commands ~= false

	if vim.fn.filereadable(config.todotxt) == 0 then vim.fn.writefile({}, config.todotxt) end

	if vim.fn.filereadable(config.donetxt) == 0 then vim.fn.writefile({}, config.donetxt) end

	if config.create_commands then
		vim.api.nvim_create_user_command(
			"TodoTxtOpen",
			function() require("todotxt").open_todo_file() end,
			{ nargs = 0, desc = "Open the todo.txt file in a new split" }
		)

		vim.api.nvim_create_user_command(
			"DoneTxtOpen",
			function() require("todotxt").open_done_file() end,
			{ nargs = 0, desc = "Open the done.txt file in a new split" }
		)

		vim.api.nvim_create_autocmd("FileType", {
			pattern = "todotxt",
			desc = "Set up commands for todotxt.nvim",
			augroup = vim.api.nvim_create_augroup("TodoTxtCommands", { clear = true }),
			callback = function(event)
				vim.api.nvim_buf_create_user_command(
					event.buf,
					"TodoTxtToggle",
					function() require("todotxt").toggle_todo_state() end,
					{ nargs = 0, desc = "Toggle the todo state of the current line" }
				)

				vim.api.nvim_buf_create_user_command(
					event.buf,
					"TodoTxtSort",
					function() require("todotxt").sort_tasks() end,
					{ nargs = 0, desc = "Sort the tasks in the todo.txt file" }
				)

				vim.api.nvim_buf_create_user_command(
					event.buf,
					"TodoTxtSortByPriority",
					function() require("todotxt").sort_tasks_by_priority() end,
					{ nargs = 0, desc = "Sort the tasks in the todo.txt file by priority" }
				)

				vim.api.nvim_buf_create_user_command(
					event.buf,
					"TodoTxtSortByProject",
					function() require("todotxt").sort_tasks_by_project() end,
					{ nargs = 0, desc = "Sort the tasks in the todo.txt file by project" }
				)

				vim.api.nvim_buf_create_user_command(
					event.buf,
					"TodoTxtSortByContext",
					function() require("todotxt").sort_tasks_by_context() end,
					{ nargs = 0, desc = "Sort the tasks in the todo.txt file by context" }
				)

				vim.api.nvim_buf_create_user_command(
					event.buf,
					"TodoTxtSortByDueDate",
					function() require("todotxt").sort_tasks_by_due_date() end,
					{ nargs = 0, desc = "Sort the tasks in the todo.txt file by due date" }
				)
			end,
		})
	end
end

todotxt.config = config

return todotxt
