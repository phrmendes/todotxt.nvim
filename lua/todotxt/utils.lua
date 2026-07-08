---
--- General-purpose utilities for the todotxt plugin.
---
--- ==============================================================================
--- @module "todotxt.utils"

local parser = require("todotxt.parser")

--- @type { todotxt: WindowParameters, donetxt: WindowParameters }
local state = { todotxt = { buf = -1, win = -1 }, donetxt = { buf = -1, win = -1 } }

local utils = {}
utils.floating = {}

utils.DATE_FORMAT = "%Y-%m-%d"

--- Get the creation date from a task line
--- @param line string
--- @return string|osdate
utils.get_creation_date = function(line)
	local parsed = parser.parse(line)
	if parsed.is_completed then return parsed.date.completion or "9999-12-31" end
	return parsed.date.creation or "9999-12-31"
end

--- Get the priority letter from a task line
--- @param line string
--- @return string
utils.get_priority = function(line) return parser.parse(line).priority or "Z" end

--- Strip formatting tokens for comparison
--- @param line string
--- @return string
utils.get_comparable_text = function(line) return parser.parse(line).description end

--- Check if a buffer has meaningful content
--- @param bufnr number|nil
--- @return boolean
utils.buffer_has_content = function(bufnr)
	bufnr = bufnr or 0
	local lines = utils.get_lines(bufnr)
	return #lines > 1 or (#lines == 1 and lines[1] ~= "")
end

--- Extract priority and remaining text from a line
--- @param line string
--- @return string|nil priority
--- @return string rest
utils.extract_priority = function(line)
	local parsed = parser.parse(line)
	local priority = parsed.priority
	if priority then return "(" .. priority .. ")", parsed.description end
	return nil, line
end

--- Format a new todo entry with the current date
--- @param input string
--- @return string
utils.format_new_todo = function(input)
	local parsed = parser.parse(input)
	if parsed.date and parsed.date.creation then return input end
	parsed.date = parsed.date or {}
	parsed.date.creation = os.date(utils.DATE_FORMAT)
	return parser.build(parsed)
end

--- Update an open buffer with new lines if it matches the file path
--- @param file_path string
--- @param lines string[]
--- @param exclude_buf number|nil
utils.update_buffer_if_open = function(file_path, lines, exclude_buf)
	local buf = vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(buf)

	if bufname == file_path and buf ~= exclude_buf then utils.set_lines(buf, lines) end

	vim.iter(state):each(function(_, state_info)
		if type(state_info) ~= "table" or not state_info.buf or not vim.api.nvim_buf_is_valid(state_info.buf) then
			return
		end

		local name = vim.api.nvim_buf_get_name(state_info.buf)
		if name == file_path and state_info.buf ~= exclude_buf then utils.set_lines(state_info.buf, lines) end
	end)
end

--- Sort lines in the current buffer using a comparator
--- @param sorter fun(a: string, b: string): boolean
utils.sort_table = function(sorter)
	local lines = utils.get_lines()
	table.sort(lines, sorter)
	utils.set_lines(0, lines)
end

--- Create a floating window
--- @param opts WindowOptions|nil
--- @return WindowParameters
utils.floating.create = function(opts)
	opts = opts or {}
	local buf = vim.api.nvim_buf_is_valid(opts.buf) and opts.buf or vim.api.nvim_create_buf(false, false)
	local width = math.floor(vim.o.columns * (opts.width or 0.75))
	local height = math.floor(vim.o.lines * (opts.height or 0.75))

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = opts.style or "minimal",
		border = opts.border or "rounded",
		title = " " .. opts.title .. " ",
		title_pos = "center",
	})

	return { buf = buf, win = win }
end

--- Open or close a floating file window
--- @param file_path string
--- @param file "todotxt"|"donetxt"
--- @param title string|nil
utils.floating.toggle = function(file_path, file, title)
	if vim.api.nvim_win_is_valid(state[file].win) then
		utils.floating.close(file_path, file)
		return
	end

	utils.floating.open(file_path, file, title or "todo.txt")

	local ok, gt = pcall(require, "todotxt.ghost_text")
	if ok and gt then gt.update() end
end

--- Save and hide an open floating window.
--- @param file_path string
--- @param file "todotxt"|"donetxt"
utils.floating.close = function(file_path, file)
	vim.api.nvim_buf_call(state[file].buf, function()
		if vim.uv.fs_stat(file_path) or utils.buffer_has_content() then pcall(function() vim.cmd("silent write!") end) end
	end)

	vim.api.nvim_win_hide(state[file].win)
end

--- Open a file in a floating window, reusing an existing buffer if available.
--- @param file_path string
--- @param file "todotxt"|"donetxt"
--- @param title string
utils.floating.open = function(file_path, file, title)
	local existing = vim.fn.bufnr(file_path)

	if existing ~= -1 and vim.api.nvim_buf_is_valid(existing) then
		state[file] = utils.floating.create({ buf = existing, title = title })
		return
	end

	state[file] = utils.floating.create({ buf = state[file].buf, title = title })

	vim.api.nvim_win_call(state[file].win, function()
		vim.api.nvim_buf_set_name(0, file_path)

		if vim.uv.fs_stat(file_path) then
			vim.cmd("edit " .. vim.fn.fnameescape(file_path))
			state[file].buf = vim.api.nvim_get_current_buf()
		end

		vim.bo.buflisted = false
	end)

	vim.keymap.set("n", "q", function()
		pcall(function() vim.cmd("silent write!") end)
		vim.cmd("quit")
	end, { buffer = state[file].buf, desc = "Close floating window" })
end

--- Get current buffer, cursor row, and line content
--- @return integer buf
--- @return integer start_row
--- @return string line
utils.get_infos = function()
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_win_get_buf(win)
	local start_row = vim.api.nvim_win_get_cursor(win)[1] - 1
	local line = utils.get_line(buf, start_row)

	return buf, start_row, line
end

--- Replace lines in a buffer. Defaults to the entire buffer.
--- @param buf integer
--- @param lines string[]
--- @param start_row? integer
--- @param end_row? integer
utils.set_lines = function(buf, lines, start_row, end_row)
	vim.api.nvim_buf_set_lines(buf, start_row or 0, end_row or -1, false, lines)
end

--- Replace a single line in a buffer.
--- @param buf integer
--- @param row integer
--- @param text string
utils.set_line = function(buf, row, text) utils.set_lines(buf, { text }, row, row + 1) end

--- Get lines from a buffer. Defaults to entire current buffer.
--- @param buf? integer
--- @param start_row? integer
--- @param end_row? integer
--- @return string[]
utils.get_lines = function(buf, start_row, end_row)
	return vim.api.nvim_buf_get_lines(buf or 0, start_row or 0, end_row or -1, false)
end

--- Get a single line from a buffer.
--- @param buf integer
--- @param row integer
--- @return string
utils.get_line = function(buf, row) return utils.get_lines(buf, row, row + 1)[1] end

--- Get todo.txt lines and active buffer
--- @param config Setup
--- @return string[]
--- @return number|nil
utils.get_todo_source = function(config)
	local current_buf = vim.api.nvim_get_current_buf()

	if vim.api.nvim_buf_get_name(current_buf) == config.todotxt then return utils.get_lines(current_buf), current_buf end

	if
		vim.api.nvim_buf_is_valid(state.todotxt.buf) and vim.api.nvim_buf_get_name(state.todotxt.buf) == config.todotxt
	then
		return utils.get_lines(state.todotxt.buf), state.todotxt.buf
	end

	return vim.uv.fs_stat(config.todotxt) and vim.fn.readfile(config.todotxt) or {}, nil
end

--- Highlight todotxt syntax in input text for vim.ui.input
--- @param text string
--- @return table
utils.highlight_input = function(text)
	local highlights = {}
	local map = {
		priority = "keyword",
		date = "comment",
		kv = "comment",
		project = "string",
		context = "type",
		comment = "comment",
	}

	for _, cap in ipairs(require("todotxt.parser.ts").captures(text)) do
		local group = map[cap.name]
		if group then table.insert(highlights, {
			cap.col_start,
			cap.col_end,
			"@" .. group,
		}) end
	end

	return highlights
end

--- Get a metadata value by key from a task line
--- @param line string
--- @param key string
--- @return string|nil
utils.get_metadata_value = function(line, key) return parser.parse(line).kv[key] end

return utils
