---
--- A lua version of the [`todotxt.vim`](https://github.com/freitass/todo.txt-vim) plugin for Neovim.
---
--- MIT License Copyright (c) 2024 Pedro Mendes
---
--- ==============================================================================
--- @module "todotxt"

local comparators = require("todotxt.comparators")
local patterns = require("todotxt.patterns")
local sorter = require("todotxt.sorter")
local state = require("todotxt.state")
local task = require("todotxt.task")
local utils = require("todotxt.utils")

local todotxt = {}
local config = {}
local group = vim.api.nvim_create_augroup("TodoTxtCommands", { clear = true })

--- Setup configuration for the todotxt module.
--- @class Setup
--- @field todotxt string: Path to the todo.txt file
--- @field donetxt string: Path to the done.txt file
--- @field create_commands boolean: Whether to create commands for the functions

--- Floating window options.
--- @class WindowOptions
--- @field width number: Width of the window
--- @field height number: Height of the window
--- @field border string: Border of the window
--- @field style string: Style of the window
--- @field buf number: Buffer that the window will be attached
--- @field title string: Title of the window

--- Floating window parameters.
--- @class WindowParameters
--- @field win number: ID of the window
--- @field buf number: ID of the buffer

--- @alias SortComparator fun(a: string, b: string): boolean
--- @alias SortFunction fun(): nil

--- Opens the todo.txt file in a floating window.
--- @return nil
todotxt.toggle_todotxt = function() utils.toggle_floating_file(config.todotxt, "todotxt") end

--- Opens the done.txt file in a floating window.
--- @return nil
todotxt.toggle_donetxt = function() utils.toggle_floating_file(config.donetxt, "donetxt", "done.txt") end

--- Toggles the todo state of the current line in a todo.txt file.
--- If the line starts with "x YYYY-MM-DD ", it removes it to mark as not done.
--- Otherwise, it adds "x YYYY-MM-DD " at the beginning to mark as done.
--- @return nil
todotxt.toggle_todo_state = function()
	local buf, start_row, line = utils.get_infos()

	local new_line

	if task.is_completed(line) then
		new_line = task.format_as_uncompleted(line)
	else
		new_line = task.format_as_completed(line)
	end

	vim.api.nvim_buf_set_lines(buf, start_row, start_row + 1, false, { new_line })
end

--- Sorts the tasks in the open buffer by completion status, priority, and text.
--- @return nil
todotxt.sort_tasks = sorter.create(comparators.default)

--- Sorts the tasks in the open buffer by priority.
--- @return nil
todotxt.sort_tasks_by_priority = sorter.create(comparators.priority)

--- Sorts the tasks in the open buffer by project.
--- @return nil
todotxt.sort_tasks_by_project = sorter.create(comparators.project)

--- Sorts the tasks in the open buffer by context.
--- @return nil
todotxt.sort_tasks_by_context = sorter.create(comparators.context)

--- Sorts the tasks in the open buffer by due date.
--- @return nil
todotxt.sort_tasks_by_due_date = sorter.create(comparators.due_date)

--- Cycles the priority of the current task between A, B, C, and no priority.
--- @return nil
todotxt.cycle_priority = function()
	local buf, start_row, line = utils.get_infos()

	if line == "" then
		vim.api.nvim_buf_set_lines(buf, start_row, start_row + 1, false, { "(A) " })
		return
	end

	local is_completed = task.is_completed(line)
	local current_priority = utils.priority_letter(line)
	local priorities = { A = "B", B = "C", C = nil, Z = "A" }
	local new_priority_letter = priorities[current_priority]

	local new_line

	if new_priority_letter then
		if current_priority ~= "Z" then
			new_line = line:gsub(patterns.priority, "(" .. new_priority_letter .. ")")
		else
			if is_completed then
				local completion_prefix = line:match(patterns.completed)
				new_line = "x (" .. new_priority_letter .. ") " .. line:sub(#completion_prefix + 1):gsub("^%s+", "")
			else
				new_line = "(" .. new_priority_letter .. ") " .. line
			end
		end
	else
		new_line = line:gsub(patterns.priority .. "%s+", "")
	end

	vim.api.nvim_buf_set_lines(0, start_row, start_row + 1, false, { new_line })
end

--- Captures a new todo entry with the current date.
--- @return nil
todotxt.capture_todo = function()
	vim.ui.input({ prompt = "New Todo: " }, function(input)
		if not input or input == "" then
			vim.notify("No input provided.", vim.log.levels.ERROR, { title = "todo.txt" })
			return
		end

		local lines
		local new_todo = utils.format_new_todo(input)
		local buf = vim.api.nvim_get_current_buf()
		local bufname = vim.api.nvim_buf_get_name(buf)

		if bufname == config.todotxt then
			lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			table.insert(lines, new_todo)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			return
		end

		lines = vim.fn.readfile(config.todotxt)
		table.insert(lines, new_todo)
		vim.fn.writefile(lines, config.todotxt)
	end)
end

--- Moves all done tasks from the todo.txt file to the done.txt file.
--- @return nil
todotxt.move_done_tasks = function()
	local todo_buf = state.todotxt.buf
	local todo_lines

	if vim.api.nvim_buf_is_valid(todo_buf) and vim.bo[todo_buf].modified then
		todo_lines = vim.api.nvim_buf_get_lines(todo_buf, 0, -1, false)
	else
		todo_lines = vim.fn.readfile(config.todotxt)
	end

	local done_lines = {}

	if vim.fn.filereadable(config.donetxt) == 1 then done_lines = vim.fn.readfile(config.donetxt) end

	local remaining_todo_lines = {}
	local moved_count = 0

	vim.iter(todo_lines):each(function(line)
		if task.is_completed(line) then
			table.insert(done_lines, line)
			moved_count = moved_count + 1
		else
			table.insert(remaining_todo_lines, line)
		end
	end)

	if moved_count == 0 then
		vim.notify("No completed tasks found to move.", vim.log.levels.WARN, { title = "todo.txt" })
		return
	end

	local files = {
		[config.todotxt] = remaining_todo_lines,
		[config.donetxt] = done_lines,
	}

	vim.iter(pairs(files)):each(function(k, v)
		vim.fn.writefile(v, k)
		utils.update_buffer_if_open(k, v)
	end)

	vim.notify(
		string.format("Moved %d completed task(s) to %s.", moved_count, config.donetxt),
		vim.log.levels.INFO,
		{ title = "todo.txt" }
	)
end

--- Setup function
--- @param opts Setup
todotxt.setup = function(opts)
	opts = opts or {}
	config.todotxt = opts.todotxt or vim.env.HOME .. "/Documents/todo.txt"
	config.donetxt = opts.donetxt or vim.env.HOME .. "/Documents/done.txt"
	config.create_commands = opts.create_commands ~= false

	if vim.fn.filereadable(config.todotxt) == 0 then vim.fn.writefile({}, config.todotxt) end

	if config.create_commands then
		vim.api.nvim_create_user_command("TodoTxt", function() require("todotxt").toggle_todotxt() end, {
			nargs = 0,
			desc = "Toggle the todo.txt file in a floating window",
		})

		vim.api.nvim_create_user_command("DoneTxt", function() require("todotxt").toggle_donetxt() end, {
			nargs = 0,
			desc = "Toggle the done.txt file in a floating window",
		})
	end
end

todotxt.config = config

return todotxt
