local patterns = require("todotxt.patterns")
local state = require("todotxt.state")

local utils = {}

--- Extracts creation date from a task line
--- @param line string The task line
--- @return string|nil date The creation date in YYYY-MM-DD format, or nil if not found
utils.creation_date = function(line)
	local clean_line = line:gsub(patterns.completed, ""):gsub(patterns.priority_with_space, "")
	local date = clean_line:match("^%s*(" .. patterns.date .. ")")
	return date or "9999-12-31"
end

--- Extracts the priority letter from a line
--- @param line string The line to check
--- @return string|nil letter The priority letter or nil
utils.priority_letter = function(line) return line:match(patterns.priority_letter) or "Z" end

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

--- Checks if a buffer has meaningful content (not just empty lines)
--- @param bufnr number|nil Buffer number (defaults to current buffer)
--- @return boolean has_content True if buffer has non-empty content
utils.buffer_has_content = function(bufnr)
	bufnr = bufnr or 0
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	return #lines > 1 or (#lines == 1 and lines[1] ~= "")
end

--- Extracts the priority and rest of text from a line
--- @param line string The line to extract from
--- @return string|nil priority The priority with parentheses, or nil
--- @return string rest The rest of the line without priority
utils.extract_priority = function(line)
	local priority = line:match("^" .. patterns.priority)
	local rest = line

	if priority then rest = rest:gsub("^" .. patterns.priority_with_space, "") end

	return priority, rest
end

--- Formats a new todo with appropriate date
--- @param input string Raw input string
--- @return string todo Formatted todo entry
utils.format_new_todo = function(input)
	local priority, rest = utils.extract_priority(input)
	local text_to_check = priority and rest or input

	if text_to_check:match("^%s*" .. patterns.date) then return input end

	local date = utils.get_current_date()

	if priority then return priority .. " " .. date .. " " .. rest end

	return date .. " " .. input
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
--- @param file "todotxt"|"donetxt" State key
--- @param title string | nil Title of the window
--- @return nil
utils.toggle_floating_file = function(file_path, file, title)
	if vim.api.nvim_win_is_valid(state[file].win) then
		vim.api.nvim_buf_call(state[file].buf, function()
			if vim.fn.filereadable(file_path) == 1 or utils.buffer_has_content() then vim.cmd("silent write!") end
		end)
		vim.api.nvim_win_hide(state[file].win)
		return
	end

	state[file] = utils.create_floating_window({
		buf = state[file].buf,
		title = title or "todo.txt",
	})

	vim.api.nvim_buf_call(state[file].buf, function() vim.cmd("edit " .. file_path .. " | setlocal nobuflisted") end)

	vim.keymap.set("n", "q", function()
		if vim.fn.filereadable(file_path) == 1 or utils.buffer_has_content() then
			vim.cmd("silent write! | q")
		else
			vim.cmd("q")
		end
	end, {
		buffer = state[file].buf,
		desc = "todo.txt: exit window with `q`",
	})
end

--- Return infos about the current window
--- @return integer buf
--- @return integer start_row
--- @return string line
utils.get_infos = function()
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_win_get_buf(win)
	local start_row = vim.api.nvim_win_get_cursor(win)[1] - 1
	local line = vim.api.nvim_buf_get_lines(buf, start_row, start_row + 1, false)[1]

	return buf, start_row, line
end

return utils
