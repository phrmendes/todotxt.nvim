---
--- In-process LSP server for todotxt files.
---
--- Provides completion, formatting, code actions, references,
--- rename, and diagnostics through Neovim's vim.lsp.start().
---
--- ==============================================================================
--- @module "todotxt.lsp"

local parser = require("todotxt.parser")
local utils = require("todotxt.lsp.utils")

local get_line = require("todotxt.utils").get_line
local get_lines = require("todotxt.utils").get_lines

local Methods = vim.lsp.protocol.Methods

--- @class todotxt.lsp
local lsp = { handlers = {} }

local config = {}

local commands = {
	{ name = "todotxt.toggle_done", title = "Toggle done" },
	{ name = "todotxt.cycle_priority", title = "Cycle priority" },
	{ name = "todotxt.sort.default", title = "Sort tasks" },
	{ name = "todotxt.sort.priority", title = "Sort by priority" },
	{ name = "todotxt.sort.project", title = "Sort by project" },
	{ name = "todotxt.sort.context", title = "Sort by context" },
	{ name = "todotxt.sort.due_date", title = "Sort by due date" },
	{ name = "todotxt.move_done", title = "Move done tasks" },
}

--- Returns the URI of the current buffer.
--- @return string
local function bufuri() return vim.uri_from_fname(vim.api.nvim_buf_get_name(0)) end

--- Resolves the +project or @context tag at a cursor position.
--- @param position { line: integer, character: integer }
--- @return todotxt.lsp.Tag|nil
local function resolve_tag(position)
	local line = get_line(0, position.line)

	if not line then return nil end

	return utils.get_tag_under_cursor(line, parser.parse(line), position.character)
end

--- @param opts { ring: Priority, metadata: table<string,MetadataConfig> }
--- @return nil
lsp.set_config = function(opts)
	config.ring = opts.ring
	config.metadata = opts.metadata or {}
end

--- @param buf integer
--- @return integer? client_id
lsp.start = function(buf)
	return vim.lsp.start({
		name = "todotxt",
		cmd = function()
			return {
				request = function(method, params, callback) return utils.dispatch(lsp.handlers, method, params, callback) end,
				notify = function(method, params) return utils.dispatch(lsp.handlers, method, params) end,
				is_closing = function() end,
				terminate = function() end,
			}
		end,
	}, { bufnr = buf, silent = true })
end

--- @param _ lsp.InitializeParams
--- @param callback fun(err?: lsp.ResponseError, result: lsp.InitializeResult)
--- @return nil
lsp.handlers[Methods.initialize] = function(_, callback)
	callback(nil, {
		capabilities = {
			completionProvider = { triggerCharacters = { "(", "+", "@" } },
			documentFormattingProvider = true,
			codeActionProvider = true,
			executeCommandProvider = {
				commands = (function()
					local names = vim.iter(commands):map(function(c) return c.name end):totable()

					vim.iter(vim.tbl_keys(config.metadata)):each(function(key)
						table.insert(names, "todotxt.sort.metadata." .. key)
					end)

					return names
				end)(),
			},
			referencesProvider = true,
			renameProvider = { prepareProvider = true },
			textDocumentSync = 1,
		},
		serverInfo = {
			name = "todotxt",
			version = "1.0.0",
		},
	})
end

--- @param params lsp.CompletionParams
--- @param callback fun(err?: lsp.ResponseError, result: lsp.CompletionItem[])
--- @return nil
lsp.handlers[Methods.textDocument_completion] = function(params, callback)
	local trigger = params.context and params.context.triggerCharacter
	local pos = params.position
	local data = utils.gather(0)
	data.ring = config.ring
	callback(nil, { items = utils.build_items(data, trigger, pos), isIncomplete = true })
end

--- @param _ lsp.DocumentFormattingParams
--- @param callback fun(err?: lsp.ResponseError, result: lsp.TextEdit[])
--- @return nil
lsp.handlers[Methods.textDocument_formatting] = function(_, callback)
	local edits = {}

	vim.iter(get_lines()):enumerate():each(function(i, line)
		if line == "" then return end

		local parsed = parser.parse(line)
		local parts = {}

		if parsed.is_completed then
			table.insert(parts, "x")
			if parsed.priority then table.insert(parts, "(" .. parsed.priority .. ")") end
			if parsed.date.completion then table.insert(parts, parsed.date.completion) end
		else
			if parsed.priority then table.insert(parts, "(" .. parsed.priority .. ")") end
		end
		if parsed.date.creation then table.insert(parts, parsed.date.creation) end

		local desc = utils.get_description(parsed.description)

		if desc and desc ~= "" then table.insert(parts, desc) end

		vim.iter(parsed.kv):each(function(k, v) table.insert(parts, k .. ":" .. v) end)
		vim.iter(parsed.contexts):each(function(ctx) table.insert(parts, "@" .. ctx) end)
		vim.iter(parsed.projects):each(function(prj) table.insert(parts, "+" .. prj) end)

		local formatted = table.concat(parts, " ")

		if formatted == line then return end

		table.insert(edits, {
			newText = formatted,
			range = { start = { line = i - 1, character = 0 }, ["end"] = { line = i - 1, character = #line } },
		})
	end)

	callback(nil, edits)
end

--- @param _ lsp.CodeActionParams
--- @param callback fun(err?: lsp.ResponseError, result: lsp.CodeAction[])
--- @return nil
lsp.handlers[Methods.textDocument_codeAction] = function(_, callback)
	local metacommands = vim
		.iter(vim.tbl_keys(config.metadata))
		:map(function(key)
			local title = "Sort by " .. key
			return {
				title = title,
				command = {
					title = title,
					command = "todotxt.sort.metadata." .. key,
					arguments = {},
				},
			}
		end)
		:totable()

	local actions = vim
		.iter(commands)
		:map(
			function(cmd)
				return {
					title = cmd.title,
					command = { title = cmd.title, command = cmd.name, arguments = {} },
				}
			end
		)
		:totable()

	vim.list_extend(actions, metacommands)

	callback(nil, actions)
end

--- @param params lsp.ExecuteCommandParams
--- @param callback fun(err?: lsp.ResponseError, result: any)
--- @return nil
lsp.handlers[Methods.workspace_executeCommand] = function(params, callback)
	local todotxt = require("todotxt")

	local fns = {
		["todotxt.toggle_done"] = todotxt.toggle_todo_state,
		["todotxt.cycle_priority"] = todotxt.cycle_priority,
		["todotxt.sort.default"] = todotxt.sort_tasks,
		["todotxt.sort.priority"] = todotxt.sort_tasks_by_priority,
		["todotxt.sort.project"] = todotxt.sort_tasks_by_project,
		["todotxt.sort.context"] = todotxt.sort_tasks_by_context,
		["todotxt.sort.due_date"] = todotxt.sort_tasks_by_due_date,
		["todotxt.move_done"] = todotxt.move_done_tasks,
	}

	local fn = fns[params.command]

	if not fn then
		local key = params.command:match("^todotxt%.sort%.metadata%.(.+)$")

		if key then
			local ok = pcall(todotxt.sort_by_metadata, key)
			if not ok then return callback({ code = 2, message = "Command failed" }, {}) end
			return callback(nil, {})
		end

		return callback({ code = 1, message = "Unknown command: " .. params.command }, {})
	end

	local ok = pcall(fn)

	if not ok then return callback({ code = 2, message = "Command failed" }, {}) end

	callback(nil, {})
end

--- @param params lsp.ReferenceParams
--- @param callback fun(err?: lsp.ResponseError, result: lsp.Location[])
--- @return nil
lsp.handlers[Methods.textDocument_references] = function(params, callback)
	local tag = resolve_tag(params.position)

	if not tag then return callback(nil, {}) end

	local bufname = bufuri()

	local locations = vim
		.iter(get_lines())
		:enumerate()
		:map(function(i, l) return utils.make_location(bufname, i, l, tag.prefix, tag.name) end)
		:filter(function(v) return v ~= nil end)
		:totable()

	callback(nil, locations)
end

--- @param params lsp.PrepareRenameParams
--- @param callback fun(err?: lsp.ResponseError, result: lsp.PrepareRenameResult?)
--- @return nil
lsp.handlers[Methods.textDocument_prepareRename] = function(params, callback)
	local tag = resolve_tag(params.position)

	if not tag then return callback(nil, nil) end

	callback(nil, {
		start = { line = params.position.line, character = tag.col - 1 },
		["end"] = { line = params.position.line, character = tag.col - 1 + #tag.name + 1 },
	})
end

--- @param params lsp.RenameParams
--- @param callback fun(err?: lsp.ResponseError, result: lsp.WorkspaceEdit?)
--- @return nil
lsp.handlers[Methods.textDocument_rename] = function(params, callback)
	local tag = resolve_tag(params.position)

	if not tag then return callback(nil, nil) end

	if not params.newName or params.newName == "" then
		return callback({ code = 1, message = "Invalid name: cannot be empty" }, {})
	end

	local new_name = params.newName:gsub("^[+@]", "")

	if not new_name:match("^[^%s]+$") then
		return callback({ code = 1, message = "Invalid name: cannot contain spaces" }, {})
	end

	local edits = vim
		.iter(get_lines())
		:enumerate()
		:map(function(i, l) return utils.make_text_edit(i, l, tag.prefix, tag.name, new_name) end)
		:filter(function(v) return v ~= nil end)
		:totable()

	local bufname = bufuri()

	callback(nil, { changes = { [bufname] = edits } })
end

lsp.handlers[Methods.shutdown] = function(_, callback) callback(nil, nil) end

lsp.handlers[Methods.exit] = function(_, callback) callback(nil, nil) end

return lsp
