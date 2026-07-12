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

--- @type Setup
local config = {}

local Priority = require("todotxt.priority")
local comparators = require("todotxt.comparators")
local lsp = require("todotxt.lsp")
local parser = require("todotxt.parser")
local sorter = require("todotxt.sorter")
local task = require("todotxt.task")
local utils = require("todotxt.utils")

--- Opens the todo.txt file in a floating window.
--- @return nil
todotxt.toggle_todotxt = function() utils.floating.toggle(config.todotxt, "todotxt") end

--- Opens the done.txt file in a floating window.
--- @return nil
todotxt.toggle_donetxt = function() utils.floating.toggle(config.donetxt, "donetxt", "done.txt") end

--- Toggles the todo state of the current line in a todo.txt file.
--- If the line starts with "x YYYY-MM-DD ", it removes it to mark as not done.
--- Otherwise, it adds "x YYYY-MM-DD " at the beginning to mark as done.
--- @return nil
todotxt.toggle_todo_state = function()
	local buf, start_row, line = utils.get_infos()
	local target = task.is_completed(line) and task.State.TODO or task.State.DONE
	utils.set_line(buf, start_row, task.format(line, target))
end

--- Sorts the tasks in the open buffer by completion status, priority, and text.
--- @return nil
todotxt.sort_tasks = function() sorter.sort(comparators.default) end

--- Sorts the tasks in the open buffer by priority.
--- @return nil
todotxt.sort_tasks_by_priority = function() sorter.sort(comparators.priority) end

--- Sorts the tasks in the open buffer by project.
--- @return nil
todotxt.sort_tasks_by_project = function() sorter.sort(comparators.project) end

--- Sorts the tasks in the open buffer by context.
--- @return nil
todotxt.sort_tasks_by_context = function() sorter.sort(comparators.context) end

--- Sorts the tasks in the open buffer by due date.
--- @return nil
todotxt.sort_tasks_by_due_date = function() sorter.sort(comparators.due_date) end

--- Sort tasks by a user-defined metadata key
--- @param key string
todotxt.sort_by_metadata = function(key)
	local meta = config.metadata[key]
	if not meta then return end

	sorter.sort(comparators.metadata(key, meta.sort))
end

--- Cycles the priority of the current task between A, B, C, and no priority.
--- @return nil
todotxt.cycle_priority = function()
	local buf, start_row, line = utils.get_infos()

	if line == "" then
		utils.set_line(buf, start_row, "(" .. config.ring.first .. ") ")
		return
	end

	local parsed = parser.parse(line)

	if parsed.priority then
		parsed.priority = config.ring:next(parsed.priority)
	else
		parsed.priority = config.ring.first
	end

	utils.set_line(buf, start_row, parser.build(parsed))
end

--- Captures a new todo entry with the current date.
--- @return nil
todotxt.capture = function()
	vim.ui.input({
		prompt = "New Todo: ",
		highlight = utils.highlight_input,
	}, function(input)
		if not input or input == "" then
			vim.notify("No input provided.", vim.log.levels.ERROR, { title = "todo.txt" })
			return
		end

		local lines
		local new_todo = utils.format_new_todo(input)
		local buf = vim.api.nvim_get_current_buf()
		local bufname = vim.api.nvim_buf_get_name(buf)

		if bufname == config.todotxt then
			lines = utils.get_lines(buf)
			table.insert(lines, new_todo)
			utils.set_lines(buf, lines)
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
	local todo, todo_buf = utils.get_todo_source(config)
	local done = vim.uv.fs_stat(config.donetxt) and vim.fn.readfile(config.donetxt) or {}

	local remaining_todo_lines = {}
	local moved_count = 0

	vim.iter(todo):each(function(line)
		if task.is_completed(line) then
			table.insert(done, line)
			moved_count = moved_count + 1
			return
		end

		table.insert(remaining_todo_lines, line)
	end)

	if moved_count == 0 then
		vim.notify("No completed tasks found to move.", vim.log.levels.WARN, { title = "todo.txt" })
		return
	end

	if todo_buf and vim.api.nvim_buf_is_valid(todo_buf) then
		utils.set_lines(todo_buf, remaining_todo_lines)
		vim.api.nvim_buf_call(todo_buf, function() vim.cmd("silent! write") end)
		utils.update_buffer_if_open(config.todotxt, remaining_todo_lines, todo_buf)
	else
		vim.fn.writefile(remaining_todo_lines, config.todotxt)
		utils.update_buffer_if_open(config.todotxt, remaining_todo_lines)
	end

	vim.fn.writefile(done, config.donetxt)
	utils.update_buffer_if_open(config.donetxt, done)

	vim.notify(
		string.format("Moved %d completed task(s) to %s.", moved_count, vim.fs.basename(config.donetxt)),
		vim.log.levels.INFO,
		{ title = "todo.txt" }
	)
end

--- Keeping the move_done if somebody is already using it.
todotxt.move_done = todotxt.move_done_tasks

--- Toggles ghost text display
--- @return nil
todotxt.toggle_ghost_text = function() require("todotxt.ghost_text").toggle() end

--- Setup function
--- @param opts Setup
todotxt.setup = function(opts)
	opts = opts or {}
	config.todotxt = opts.todotxt or vim.fs.joinpath(vim.env.HOME, "Documents", "todo.txt")
	config.donetxt = opts.donetxt or vim.fs.joinpath(vim.env.HOME, "Documents", "done.txt")
	config.metadata = opts.metadata or {}

	config.ring = Priority.new(opts.max_priority)
	parser.use(opts.parser or "regex")

	if opts.ghost_text then require("todotxt.ghost_text").setup(opts.ghost_text) end

	if opts.lsp ~= false then
		lsp.set_config({ ring = config.ring, metadata = config.metadata })

		vim.api.nvim_create_autocmd("FileType", {
			pattern = "todotxt",
			callback = function(args) lsp.start(args.buf) end,
		})
	end

	if not vim.uv.fs_stat(config.todotxt) then vim.fn.writefile({}, config.todotxt) end

	vim.api.nvim_create_user_command("TodoTxt", function(args)
		local cmd = args.fargs[1]

		if not cmd then
			require("todotxt").toggle_todotxt()
			return
		end

		if cmd == "new" then
			require("todotxt").capture()
			return
		end

		if cmd == "ghost" then
			require("todotxt").toggle_ghost_text()
			return
		end

		vim.notify("TodoTxt: Unknown command: " .. cmd .. ". Available: new, ghost", vim.log.levels.ERROR)
	end, {
		nargs = "?",
		desc = "TodoTxt commands (default: toggle, 'new': create entry, 'ghost': toggle ghost text)",
		--- @param arg string
		complete = function(arg)
			return vim.iter({ "new", "ghost" }):filter(function(c) return c:find(arg, 1, true) end):totable()
		end,
	})

	vim.api.nvim_create_user_command("DoneTxt", function() require("todotxt").toggle_donetxt() end, {
		nargs = 0,
		desc = "Toggle the done.txt file in a floating window",
	})
end

todotxt.config = config

return todotxt
