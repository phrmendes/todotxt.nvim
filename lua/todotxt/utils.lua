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

	local bufnr = state[file].buf

	vim.api.nvim_buf_call(bufnr, function()
		-- Load file content and filter if needed
		local lines = {}
		if vim.uv.fs_stat(file_path) then
			lines = vim.fn.readfile(file_path)
			-- Filter hidden tasks only for todotxt files, not done.txt
			if file == "todotxt" and config then lines = utils.filter_visible_tasks(lines, config) end
		end

		-- Set buffer content and configure
		vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
		vim.api.nvim_buf_set_name(0, file_path)
		vim.bo.modified = false
		vim.bo.buflisted = false

		-- Mark this as a managed floating buffer to enable save interception
		vim.b[bufnr].todotxt_float = true

		-- Set up buffer-local save handler for todo.txt to preserve hidden tasks
		-- This BufWriteCmd is scoped ONLY to this floating buffer to prevent
		-- interference with normal file editing workflows (fixes issue #8)
		if file == "todotxt" and config and config.hide_tasks then
			-- Create a unique augroup for this floating buffer to ensure proper cleanup
			local group = vim.api.nvim_create_augroup("todotxt_float_save_" .. bufnr, { clear = true })

			-- Buffer-local BufWriteCmd that only affects this floating buffer
			vim.api.nvim_create_autocmd("BufWriteCmd", {
				group = group,
				buffer = bufnr, -- Buffer-scoped: only applies to this specific buffer
				callback = function(opts) return utils.handle_float_save(opts.buf, file_path, config) end,
			})

			-- Critical: Clean up autocmds when the floating context is destroyed
			-- This prevents save interception from affecting normal editing sessions
			vim.api.nvim_create_autocmd({ "WinClosed", "BufWipeout", "BufUnload", "BufWinLeave" }, {
				group = group,
				buffer = bufnr,
				once = true, -- Only run once to avoid multiple cleanup calls
				callback = function()
					-- Remove the augroup and all its autocmds
					pcall(vim.api.nvim_del_augroup_by_id, group)
					-- Clear buffer-local flags
					vim.b[bufnr].todotxt_float = nil
					vim.b[bufnr]._todotxt_saving = nil
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

--- Handles saving for floating buffers with proper file creation support.
--- This function is called by the buffer-local BufWriteCmd autocmd created for floating windows.
--- It provides robust file creation, atomic saves, and proper hidden task merging.
---
--- Key features:
--- - Supports creating new files and directories
--- - Uses atomic save (temp file + rename) for safety
--- - Merges hidden tasks when hide_tasks is enabled
--- - Prevents recursive saves with internal locking
--- - Falls back to default write behavior for non-managed buffers
---
--- @param bufnr number Buffer number of the floating buffer
--- @param file_path string Target file path to save to
--- @param config table Plugin configuration (contains hide_tasks setting)
--- @return boolean success Whether the save operation succeeded
utils.handle_float_save = function(bufnr, file_path, config)
	-- Defensive check: Only handle buffers marked as managed floating buffers
	-- This prevents interference with normal file editing (addresses issue #8)
	if not vim.b[bufnr].todotxt_float then
		-- Not a managed floating buffer: use noautocmd write to avoid recursion
		local bang = (vim.v.cmdbang == 1) and "!" or ""
		vim.cmd("noautocmd write" .. bang)
		return true
	end

	-- Prevent recursive saves
	if vim.b[bufnr]._todotxt_saving then return true end
	vim.b[bufnr]._todotxt_saving = true

	local success = false
	local error_msg = nil

	local function cleanup() vim.b[bufnr]._todotxt_saving = false end

	local function log_error(msg)
		error_msg = msg
		vim.notify("[todotxt] Save failed: " .. msg, vim.log.levels.ERROR, { title = "todo.txt" })
	end

	xpcall(function()
		-- Validate file path
		if not file_path or file_path == "" then
			log_error("Empty filename")
			return
		end

		-- Ensure target directory exists
		local dir = vim.fn.fnamemodify(file_path, ":h")
		if dir ~= "" and vim.fn.isdirectory(dir) == 0 then
			local mkdir_result = vim.fn.mkdir(dir, "p")
			if mkdir_result == 0 then
				log_error("Failed to create directory: " .. dir)
				return
			end
		end

		-- Get buffer lines and apply hidden task merging if needed
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		if config and config.hide_tasks then lines = utils.merge_with_hidden_tasks(lines, file_path, config) end

		-- Write to temporary file first for atomic save
		local tmp_path = file_path .. ".todotxt.tmp"
		local write_ok, write_err = pcall(vim.fn.writefile, lines, tmp_path)
		if not write_ok then
			log_error("Failed to write temporary file: " .. tostring(write_err))
			return
		end

		-- Atomically move temp file to final location
		local rename_ok, rename_err = pcall(function()
			-- Remove existing file if it exists (for overwrite)
			if vim.fn.filereadable(file_path) == 1 then pcall(vim.loop.fs_unlink, file_path) end

			-- Use vim.fn.rename for cross-platform compatibility
			local rename_result = vim.fn.rename(tmp_path, file_path)
			if rename_result ~= 0 then error("rename failed with code: " .. tostring(rename_result)) end
		end)

		if not rename_ok then
			-- Cleanup temp file on failure
			pcall(vim.loop.fs_unlink, tmp_path)
			log_error("Failed to finalize save: " .. tostring(rename_err))
			return
		end

		-- Mark buffer as unmodified on successful save
		vim.api.nvim_buf_set_option(bufnr, "modified", false)
		success = true
	end, function(err) log_error("Unexpected error: " .. tostring(err)) end)

	cleanup()
	return success
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

	return vim.iter(lines):filter(function(line) return not utils.should_hide_task(line, config) end):totable()
end

--- Gets only hidden tasks from a list of task lines
--- @param lines string[] List of task lines
--- @param config table Plugin configuration
--- @return string[] hidden_lines List of hidden task lines
utils.get_hidden_tasks = function(lines, config)
	if not config or not config.hide_tasks then return {} end

	return vim.iter(lines):filter(function(line) return utils.should_hide_task(line, config) end):totable()
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
	vim.iter(hidden_lines):each(function(line) table.insert(merged, line) end)

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
