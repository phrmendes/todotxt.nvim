---
--- A lua version of the [`todotxt.vim`](https://github.com/freitass/todo.txt-vim) plugin for Neovim.
---
--- MIT License Copyright (c) 2024 Pedro Mendes
---
--- ==============================================================================
--- @module 'todotxt'
local todotxt = {}
local config = {}
local utils = {}
local group = vim.api.nvim_create_augroup("TodoTxtCommands", { clear = true })

local state = {
	todotxt = { buf = -1, win = -1 },
	donetxt = { buf = -1, win = -1 },
}

local patterns = {
	completed = "^x%s+",
	completed_with_priority = "^x%s+%(%a%)%s+",
	completed_with_date = "^x%s+%d%d%d%d%-%d%d%-%d%d%s+",
	completed_with_priority_and_creation_date = "^x%s+%(%a%)%s+%d%d%d%d%-%d%d%-%d%d%s+",
	completed_with_priority_creation_and_done_date = "^x%s+%(%a%)%s+%d%d%d%d%-%d%d%-%d%d%s+%d%d%d%d%-%d%d%-%d%d%s+",
	context = "@%w+",
	date = "%d%d%d%d%-%d%d%-%d%d",
	date_with_space = "%d%d%d%d%-%d%d%-%d%d%s+",
	due_date = "due:(%d%d%d%d%-%d%d%-%d%d)",
	letter = "%a",
	priority = "%(%a%)",
	priority_letter = "%((%a)%)",
	priority_with_space = "%(%a%)%s+",
	project = "%+%w+",
}

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

--- Checks if a line is completed
--- @param line string The line to check
--- @return boolean status Whether the line is completed
utils.is_completed = function(line) return line:match(patterns.completed) ~= nil end

--- Extracts the priority letter from a line
--- @param line string The line to check
--- @return string|nil letter The priority letter or nil
utils.priority_letter = function(line) return line:match(patterns.priority_letter) end

--- Cleans up the line to make it comparable.
--- @param line string The line to process
--- @return string new_line The processed line
utils.comparable_text = function(line)
	local new_line, _ = line
		:gsub(patterns.completed_with_priority_creation_and_done_date, "")
		:gsub(patterns.completed_with_priority_and_creation_date, "")
		:gsub(patterns.completed_with_date, "")
		:gsub(patterns.completed, "")
		:gsub(patterns.priority_with_space, "")
		:gsub(patterns.date_with_space, "")
		:gsub("^%s*", "")

	return new_line
end

--- Gets current date in YYYY-MM-DD format
--- @return string|osdate date Current date
utils.get_current_date = function() return os.date("%Y-%m-%d") end

--- Formats a new todo with appropriate date
--- @param input string Raw input string
--- @return string todo Formatted todo entry
utils.format_new_todo = function(input)
	if input:match(patterns.date) then return input end

	local date = utils.get_current_date()
	local priority = input:match("^%(%a%)")

	if priority then
		local rest = input:gsub("^%(%a%)%s+", "")
		return priority .. " " .. date .. " " .. rest
	else
		return date .. " " .. input
	end
end

--- Updates the buffer if it is open.
--- @param file_path string
--- @param lines string[]
--- @return nil
utils.update_buffer_if_open = function(file_path, lines)
	local current_buf = vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(current_buf)

	if bufname == file_path then vim.api.nvim_buf_set_lines(0, 0, -1, false, lines) end
end

--- Sorts the tasks in the open buffer by a given function.
--- @param sort_func SortComparator A function that sorts the lines
--- @return nil
utils.sort_table = function(sort_func)
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	table.sort(lines, sort_func)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

--- Sorts two tasks by its completion status
--- @param a string: A task
--- @param b string: Another task
--- @return boolean
utils.sort_by_completion = function(a, b)
	local a_completed = utils.is_completed(a)
	local b_completed = utils.is_completed(b)

	if a_completed ~= b_completed then return not a_completed end

	return false
end

--- Creates a sort function that prioritizes completion status.
--- @param sort_func SortComparator The primary sorting logic to apply after completion status
--- @return SortComparator sort_func A comparison function suitable for table.sort
utils.completion_sorter = function(sort_func)
	return function(a, b)
		local completion_result = utils.sort_by_completion(a, b)
		if completion_result ~= nil then return completion_result end
		return sort_func(a, b)
	end
end

--- Creates a floating window
--- @param opts WindowOptions | nil
--- @return WindowParameters
utils.create_floating_window = function(opts)
	opts = opts or {}

	local buf = nil
	local width = opts.width or math.floor(vim.o.columns * 0.75)
	local height = opts.height or math.floor(vim.o.lines * 0.75)
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	if vim.api.nvim_buf_is_valid(opts.buf) then
		buf = opts.buf
	else
		buf = vim.api.nvim_create_buf(false, true)
	end

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = opts.style or "minimal",
		border = opts.border or "rounded",
		title = " " .. opts.title .. " ",
		title_pos = "center",
	})

	return { buf = buf, win = win }
end

--- Opens a file in a floating window.
--- @param file_path string Path to the file to open
--- @param state_key "todotxt"|"donetxt" Key in the state table
--- @param window_title string | nil Title of the window
--- @return nil
utils.toggle_floating_file = function(file_path, state_key, window_title)
	if not vim.api.nvim_win_is_valid(state[state_key].win) then
		state[state_key] = utils.create_floating_window({
			buf = state[state_key].buf,
			title = window_title or "todo.txt",
		})

		if vim.bo[state[state_key].buf].buftype ~= "todotxt" then
			vim.api.nvim_buf_call(
				state[state_key].buf,
				function() vim.cmd("edit " .. file_path .. " | setlocal nobuflisted") end
			)
		end

		vim.keymap.set("n", "q", "<cmd>silent write!<bar>q<cr>", {
			buffer = state[state_key].buf,
			desc = "todo.txt: exit window with `q`",
		})
	else
		if state_key == "todotxt" then vim.cmd("silent write!") end
		vim.api.nvim_win_hide(state[state_key].win)
	end
end

--- Creates a sort function with a specific comparator
--- @param comparator SortComparator The comparison function to use after completion sorting
--- @return SortFunction sort_func The full sorting function that can be called without arguments
utils.create_sort_function = function(comparator)
	return function() utils.sort_table(utils.completion_sorter(comparator)) end
end

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
	local start_row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, false)[1]

	if line:match(patterns.completed_with_date) then
		line = line:gsub(patterns.completed_with_date, "")
	elseif line:match(patterns.completed_with_priority_and_creation_date) then
		local priority = line:match(patterns.priority)

		line = line:gsub(patterns.completed_with_priority_and_creation_date, "")
		line = priority .. " " .. line
	elseif line:match(patterns.completed) then
		line = line:gsub(patterns.completed, "")
	else
		local date = utils.get_current_date()
		local priority = line:match(patterns.priority)

		if priority then
			local rest = line:gsub(patterns.priority_with_space, "")
			line = "x " .. priority .. " " .. date .. " " .. rest
		else
			line = "x " .. date .. " " .. line
		end
	end

	vim.api.nvim_buf_set_lines(0, start_row, start_row + 1, false, { line })
end

--- Sorts the tasks in the open buffer by completion status, priority, and text.
--- Follows the standard todo.txt sorting order:
---  1. Incomplete tasks before completed ones
---  2. Tasks sorted by priority (A-Z)
---  3. Tasks with same priority/completion sorted alphabetically
--- @return nil
todotxt.sort_tasks = utils.create_sort_function(function(a, b)
	local priority_a = utils.priority_letter(a) or "Z"
	local priority_b = utils.priority_letter(b) or "Z"

	if priority_a ~= priority_b then return priority_a < priority_b end

	local text_a = utils.comparable_text(a)
	local text_b = utils.comparable_text(b)

	return text_a < text_b
end)

--- Sorts the tasks in the open buffer by priority.
--- @return nil
todotxt.sort_tasks_by_priority = utils.create_sort_function(function(a, b)
	local priority_a = utils.priority_letter(a) or "Z"
	local priority_b = utils.priority_letter(b) or "Z"

	if priority_a == priority_b then return a < b end

	return priority_a < priority_b
end)

--- Sorts the tasks in the open buffer by project.
--- @return nil
todotxt.sort_tasks_by_project = utils.create_sort_function(function(a, b)
	local project_a = a:match(patterns.project) or "~~~"
	local project_b = b:match(patterns.project) or "~~~"

	if project_a == project_b then return a < b end

	return project_a < project_b
end)

--- Sorts the tasks in the open buffer by context.
--- @return nil
todotxt.sort_tasks_by_context = utils.create_sort_function(function(a, b)
	local context_a = a:match(patterns.context) or "~~~"
	local context_b = b:match(patterns.context) or "~~~"

	if context_a == context_b then return a < b end

	return context_a < context_b
end)

--- Sorts the tasks in the open buffer by due date.
--- @return nil
todotxt.sort_tasks_by_due_date = utils.create_sort_function(function(a, b)
	local due_date_a = a:match(patterns.due_date)
	local due_date_b = b:match(patterns.due_date)

	if due_date_a and not due_date_b then return true end
	if not due_date_a and due_date_b then return false end

	if due_date_a and due_date_b then
		if due_date_a == due_date_b then return a < b end

		return due_date_a < due_date_b
	end

	return a < b
end)

--- Cycles the priority of the current task between A, B, C, and no priority.
--- @return nil
todotxt.cycle_priority = function()
	local start_row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, false)[1]

	if line == "" then
		vim.api.nvim_buf_set_lines(0, start_row, start_row + 1, false, { "(A) " })
		return
	end

	local is_completed = utils.is_completed(line)
	local current_priority = utils.priority_letter(line)

	local new_priority_letter
	if current_priority == "A" then
		new_priority_letter = "B"
	elseif current_priority == "B" then
		new_priority_letter = "C"
	elseif current_priority == "C" then
		new_priority_letter = nil
	else
		new_priority_letter = "A"
	end

	local new_line
	if new_priority_letter then
		if current_priority then
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

		local new_todo = utils.format_new_todo(input)
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

	local done_lines = vim.fn.readfile(config.donetxt)
	local remaining_todo_lines = {}
	local moved_count = 0

	vim.iter(todo_lines):each(function(line)
		if utils.is_completed(line) then
			table.insert(done_lines, line)
			moved_count = moved_count + 1
		else
			table.insert(remaining_todo_lines, line)
		end
	end)

	if moved_count > 0 then
		vim.fn.writefile(done_lines, config.donetxt)
		vim.fn.writefile(remaining_todo_lines, config.todotxt)

		utils.update_buffer_if_open(config.todotxt, remaining_todo_lines)
		utils.update_buffer_if_open(config.donetxt, done_lines)

		vim.notify(
			string.format("Moved %d completed task(s) to %s", moved_count, config.donetxt),
			vim.log.levels.INFO,
			{ title = "todo.txt" }
		)
	else
		vim.notify("No completed tasks found to move.", vim.log.levels.WARN, { title = "todo.txt" })
	end
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
			"TodoTxt",
			function() require("todotxt").toggle_todotxt() end,
			{ nargs = 0, desc = "Toggle the todo.txt file in a floating window" }
		)

		vim.api.nvim_create_user_command(
			"DoneTxt",
			function() require("todotxt").toggle_donetxt() end,
			{ nargs = 0, desc = "Toggle the done.txt file in a floating window" }
		)

		vim.api.nvim_create_autocmd("FileType", {
			pattern = "todotxt",
			desc = "Set up commands for todotxt.nvim",
			group = group,
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
