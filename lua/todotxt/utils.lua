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
	local current_bufname = vim.api.nvim_buf_get_name(current_buf)

	if current_bufname == file_path then vim.api.nvim_buf_set_lines(current_buf, 0, -1, false, lines) end

	for _, state_info in pairs(state) do
		if type(state_info) == "table" and state_info.buf and vim.api.nvim_buf_is_valid(state_info.buf) then
			local plugin_bufname = vim.api.nvim_buf_get_name(state_info.buf)
			if plugin_bufname == file_path then vim.api.nvim_buf_set_lines(state_info.buf, 0, -1, false, lines) end
		end
	end
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
		buf = vim.api.nvim_create_buf(false, false)
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
--- @param config table | nil Plugin configuration for filtering
--- @return nil
utils.toggle_floating_file = function(file_path, file, title, config)
	if vim.api.nvim_win_is_valid(state[file].win) then
		vim.api.nvim_buf_call(state[file].buf, function()
			if vim.uv.fs_stat(file_path) or utils.buffer_has_content() then vim.cmd("silent write!") end
		end)
		vim.api.nvim_win_hide(state[file].win)
		return
	end

	state[file] = utils.create_floating_window({
		buf = state[file].buf,
		title = title or "todo.txt",
	})

	vim.api.nvim_buf_call(state[file].buf, function()
		-- Load file content and filter if needed
		local lines = {}
		if vim.uv.fs_stat(file_path) then
			lines = vim.fn.readfile(file_path)
			-- Filter hidden tasks only for todotxt files, not done.txt
			if file == "todotxt" and config then
				lines = utils.filter_visible_tasks(lines, config)
			end
		end
		
		-- Set buffer content and configure
		vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
		vim.api.nvim_buf_set_name(0, file_path)
		vim.bo.modified = false
		vim.bo.buflisted = false
		
		-- Set up custom save handler for todo.txt to preserve hidden tasks
		if file == "todotxt" and config and config.hide_tasks then
			vim.api.nvim_create_autocmd("BufWriteCmd", {
				buffer = 0,
				callback = function()
					local visible_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
					local merged_lines = utils.merge_with_hidden_tasks(visible_lines, file_path, config)
					vim.fn.writefile(merged_lines, file_path)
					vim.bo.modified = false
					return true
				end,
			})
		end
	end)

	vim.keymap.set("n", "q", function()
		if vim.uv.fs_stat(file_path) or utils.buffer_has_content() then
			if file == "todotxt" and config and config.hide_tasks then
				-- Use custom save logic for todo.txt with hidden tasks
				local visible_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
				local merged_lines = utils.merge_with_hidden_tasks(visible_lines, file_path, config)
				vim.fn.writefile(merged_lines, file_path)
				vim.cmd("q")
			else
				vim.cmd("silent write! | q")
			end
		else
			vim.cmd("q")
		end
	end, {
		buffer = state[file].buf,
		desc = "todo.txt: exit window with `q`",
	})
end

--- Extracts hidden tag value from a task line
--- @param line string The task line
--- @return number|nil hidden_value The hidden tag value or nil if not found
utils.get_hidden_tag_value = function(line)
	local hidden_value = line:match(patterns.hidden_tag)
	return hidden_value and tonumber(hidden_value) or nil
end

--- Checks if a task should be hidden based on its hidden tag
--- @param line string The task line
--- @param config table Plugin configuration
--- @return boolean should_hide True if the task should be hidden
utils.should_hide_task = function(line, config)
	if not config or not config.hide_tasks then return false end
	
	local hidden_value = utils.get_hidden_tag_value(line)
	if not hidden_value then return false end
	
	-- Hide task if h:1 or any positive value
	return hidden_value > 0
end

--- Filters out hidden tasks from a list of task lines
--- @param lines string[] List of task lines
--- @param config table Plugin configuration
--- @return string[] filtered_lines List of visible task lines
utils.filter_visible_tasks = function(lines, config)
	if not config or not config.hide_tasks then return lines end
	
	return vim.iter(lines):filter(function(line)
		return not utils.should_hide_task(line, config)
	end):totable()
end

--- Gets only hidden tasks from a list of task lines
--- @param lines string[] List of task lines
--- @param config table Plugin configuration
--- @return string[] hidden_lines List of hidden task lines
utils.get_hidden_tasks = function(lines, config)
	if not config or not config.hide_tasks then return {} end
	
	return vim.iter(lines):filter(function(line)
		return utils.should_hide_task(line, config)
	end):totable()
end

--- Merges visible tasks with hidden tasks for saving
--- @param visible_lines string[] Currently visible task lines
--- @param original_file_path string Path to the original file
--- @param config table Plugin configuration
--- @return string[] merged_lines Combined visible and hidden task lines
utils.merge_with_hidden_tasks = function(visible_lines, original_file_path, config)
	if not config or not config.hide_tasks then return visible_lines end
	
	local hidden_lines = {}
	if vim.uv.fs_stat(original_file_path) then
		local original_lines = vim.fn.readfile(original_file_path)
		hidden_lines = utils.get_hidden_tasks(original_lines, config)
	end
	
	-- Combine visible and hidden tasks
	local merged = vim.deepcopy(visible_lines)
	vim.iter(hidden_lines):each(function(line)
		table.insert(merged, line)
	end)
	
	return merged
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
