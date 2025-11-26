---
--- A lua version of the [`todotxt.vim`](https://github.com/freitass/todo.txt-vim) plugin for Neovim.
---
--- MIT License Copyright (c) 2024 Pedro Mendes
---
--- ==============================================================================
--- @module "todotxt"

require("todotxt.types")

if vim.g.loaded_todotxt then return {} end

vim.g.loaded_todotxt = true

local todotxt = {}
local config = {}

--- Opens the todo.txt file in a floating window.
--- @return nil
todotxt.toggle_todotxt = function()
	local utils = require("todotxt.utils")
	utils.toggle_floating_file(config.todotxt, "todotxt")
end

--- Opens the done.txt file in a floating window.
--- @return nil
todotxt.toggle_donetxt = function()
	local utils = require("todotxt.utils")
	utils.toggle_floating_file(config.donetxt, "donetxt", "done.txt")
end

--- Toggles the todo state of the current line in a todo.txt file.
--- If the line starts with "x YYYY-MM-DD ", it removes it to mark as not done.
--- Otherwise, it adds "x YYYY-MM-DD " at the beginning to mark as done.
--- @return nil
todotxt.toggle_todo_state = function()
	local utils = require("todotxt.utils")
	local task = require("todotxt.task")
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
todotxt.sort_tasks = function()
	local sorter = require("todotxt.sorter")
	local comparators = require("todotxt.comparators")
	sorter.create(comparators.default)()
end

--- Sorts the tasks in the open buffer by priority.
--- @return nil
todotxt.sort_tasks_by_priority = function()
	local sorter = require("todotxt.sorter")
	local comparators = require("todotxt.comparators")
	sorter.create(comparators.priority)()
end

--- Sorts the tasks in the open buffer by project.
--- @return nil
todotxt.sort_tasks_by_project = function()
	local sorter = require("todotxt.sorter")
	local comparators = require("todotxt.comparators")
	sorter.create(comparators.project)()
end

--- Sorts the tasks in the open buffer by context.
--- @return nil
todotxt.sort_tasks_by_context = function()
	local sorter = require("todotxt.sorter")
	local comparators = require("todotxt.comparators")
	sorter.create(comparators.context)()
end

--- Sorts the tasks in the open buffer by due date.
--- @return nil
todotxt.sort_tasks_by_due_date = function()
	local sorter = require("todotxt.sorter")
	local comparators = require("todotxt.comparators")
	sorter.create(comparators.due_date)()
end

--- Cycles the priority of the current task between A, B, C, and no priority.
--- @return nil
todotxt.cycle_priority = function()
	local utils = require("todotxt.utils")
	local task = require("todotxt.task")
	local patterns = require("todotxt.patterns")
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
	vim.ui.input({
		prompt = "New Todo: ",
		highlight = require("todotxt.utils").highlight_todotxt_input,
	}, function(input)
		if not input or input == "" then
			vim.notify("No input provided.", vim.log.levels.ERROR, { title = "todo.txt" })
			return
		end

		local utils = require("todotxt.utils")
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
	local task = require("todotxt.task")
	local utils = require("todotxt.utils")

	local todo_lines, todo_buf = utils.get_todo_source(config)
	local done_lines = vim.uv.fs_stat(config.donetxt) and vim.fn.readfile(config.donetxt) or {}

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

	if todo_buf then vim.api.nvim_buf_set_lines(todo_buf, 0, -1, false, remaining_todo_lines) end

	utils.update_buffer_if_open(config.todotxt, remaining_todo_lines, todo_buf)
	utils.update_buffer_if_open(config.donetxt, done_lines)

	vim.fn.writefile(remaining_todo_lines, config.todotxt)
	vim.fn.writefile(done_lines, config.donetxt)

	vim.notify(
		string.format("Moved %d completed task(s) to %s.", moved_count, vim.fn.fnamemodify(config.donetxt, ":t")),
		vim.log.levels.INFO,
		{ title = "todo.txt" }
	)
end

--- Toggles ghost text display
--- @return nil
todotxt.toggle_ghost_text = function() require("todotxt.ghost_text").toggle() end

--- Setup function
--- @param opts Setup
todotxt.setup = function(opts)
	opts = opts or {}
	config.todotxt = opts.todotxt or vim.env.HOME .. "/Documents/todo.txt"
	config.donetxt = opts.donetxt or vim.env.HOME .. "/Documents/done.txt"

	if opts.ghost_text then require("todotxt.ghost_text").setup(opts.ghost_text) end

	if not vim.uv.fs_stat(config.todotxt) then vim.fn.writefile({}, config.todotxt) end

	vim.api.nvim_create_user_command("TodoTxt", function(args)
		local cmd = args.fargs[1]

		if not cmd then
			require("todotxt").toggle_todotxt()
		elseif cmd == "new" then
			require("todotxt").capture_todo()
		elseif cmd == "ghost" then
			require("todotxt").toggle_ghost_text()
		else
			vim.notify("TodoTxt: Unknown command: " .. cmd .. ". Available: new, ghost", vim.log.levels.ERROR)
		end
	end, {
		nargs = "?",
		desc = "TodoTxt commands (default: toggle, 'new': create entry, 'ghost': toggle ghost text)",
		complete = function(arg)
			local cmds = { "new", "ghost" }
			return vim.iter(cmds):filter(function(c) return c:find(arg, 1, true) end):totable()
		end,
	})

	vim.api.nvim_create_user_command("DoneTxt", function() require("todotxt").toggle_donetxt() end, {
		nargs = 0,
		desc = "Toggle the done.txt file in a floating window",
	})
end

todotxt.config = config

return todotxt
