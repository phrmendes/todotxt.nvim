---
--- LSP utility functions for the todotxt plugin.
---
--- ==============================================================================
--- @module "todotxt.lsp.utils"

local parser = require("todotxt.parser")

local Kind = vim.lsp.protocol.CompletionItemKind

--- @class todotxt.lsp.utils
local utils = {}

--- Scans a buffer for todos-txt tags and returns deduplicated collections.
--- @param buffer integer
--- @return todotxt.lsp.GatherData
function utils.gather(buffer)
	local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
	local projects, contexts, kv = {}, {}, { keys = {}, values = {} }

	vim.iter(lines):map(parser.parse):each(function(parsed)
		vim.iter(parsed.projects):each(function(p) projects[p] = true end)
		vim.iter(parsed.contexts):each(function(c) contexts[c] = true end)
		vim.iter(parsed.kv):each(function(k, v)
			kv.keys[k] = true
			if not kv.values[k] then kv.values[k] = {} end
			kv.values[k][v] = true
		end)
	end)

	return { projects = projects, contexts = contexts, kv = kv }
end

--- Creates a CompletionItem with optional textEdit for triggered completions.
--- @param label string
--- @param kind lsp.CompletionItemKind
--- @param category string
--- @param trigger string|nil
--- @param pos table|nil
--- @return lsp.CompletionItem
local function completion_item(label, kind, category, trigger, pos)
	local item = {
		label = label,
		kind = kind,
		labelDetails = { detail = " " .. category },
		detail = category,
	}
	if trigger and pos then
		item.textEdit = {
			range = {
				start = { line = pos.line, character = pos.character - 1 },
				["end"] = { line = pos.line, character = pos.character },
			},
			newText = label,
		}
	end
	return item
end

--- Builds a list of CompletionItem from collected data.
--- @param data todotxt.lsp.GatherData
--- @param trigger string|nil The completion trigger character ("(", "+", "@") or nil for manual invocation.
--- @param pos table|nil Cursor position { line: integer, character: integer } when triggered.
--- @return lsp.CompletionItem[]
function utils.build_items(data, trigger, pos)
	local items = {}
	local all = trigger == nil

	local categories = {
		{
			cond = function() return (all or trigger == "(") and data.ring end,
			src = data.ring and data.ring:as_list() or {},
			prefix = "(",
			suffix = ")",
			kind = Kind.Keyword,
			cat = "Priority",
		},
		{
			cond = function() return all or trigger == "+" end,
			src = data.projects,
			prefix = "+",
			kind = Kind.Struct,
			cat = "Project",
		},
		{
			cond = function() return all or trigger == "@" end,
			src = data.contexts,
			prefix = "@",
			kind = Kind.Variable,
			cat = "Context",
		},
		{
			cond = function() return all end,
			src = data.kv.keys,
			prefix = "",
			suffix = ":",
			kind = Kind.Property,
			cat = "Key",
		},
	}

	vim.iter(categories):each(function(c)
		if not c.cond() then return end

		vim.iter(c.src):each(
			function(v, _)
				table.insert(items, completion_item(c.prefix .. v .. (c.suffix or ""), c.kind, c.cat, trigger, pos))
			end
		)
	end)

	return items
end

--- Strips +project, @context, and key:value tags from a description.
--- @param text string
--- @return string
function utils.get_description(text)
	local stripped = text
		:gsub("%+[^%s]+", "") -- +project
		:gsub("@[^%s]+", "") -- @context
		:gsub("[%w-]+:%S+", "") -- key:value

	return stripped:gsub("%s+", " "):match("^%s*(.-)%s*$")
end

--- Finds the +project or @context under the cursor.
--- @param line string
--- @param parsed ParsedLine
--- @param col integer 0-indexed cursor column
--- @return todotxt.lsp.Tag|nil col is 1-indexed start of the prefix
function utils.get_tag_under_cursor(line, parsed, col)
	local tags = {}

	vim.iter(parsed.projects):each(function(n) table.insert(tags, { prefix = "+", name = n }) end)
	vim.iter(parsed.contexts):each(function(n) table.insert(tags, { prefix = "@", name = n }) end)

	return vim.iter(tags):find(function(t)
		local s = line:find(t.prefix .. t.name)
		if not s then return false end
		t.col = s
		return col >= s - 1 and col < s - 1 + #t.name
	end)
end

--- Returns the range of a tag prefix+name in a line.
--- @param i integer 1-indexed line number
--- @param l string
--- @param prefix string
--- @param name string
--- @return { start: { line: integer, character: integer }, ["end"]: { line: integer, character: integer } }|nil
local function tag_range(i, l, prefix, name)
	local s, e = l:find(prefix .. name)

	if not s then return nil end

	return {
		start = { line = i - 1, character = s - 1 },
		["end"] = { line = i - 1, character = e },
	}
end

--- Creates a Location for a tag match on a line.
--- @param bufname string
--- @param i integer 1-indexed line number
--- @param l string
--- @param prefix string
--- @param name string
--- @return lsp.Location|nil
function utils.make_location(bufname, i, l, prefix, name)
	local range = tag_range(i, l, prefix, name)

	if not range then return nil end

	return { uri = bufname, range = range }
end

--- Creates a TextEdit for a tag rename on a line.
--- @param i integer 1-indexed line number
--- @param l string
--- @param prefix string
--- @param name string
--- @param new_name string
--- @return lsp.TextEdit|nil
function utils.make_text_edit(i, l, prefix, name, new_name)
	local range = tag_range(i, l, prefix, name)

	if not range then return nil end

	return { range = range, newText = prefix .. new_name }
end

--- Dispatches an LSP method call to the matching handler.
--- @param handlers table<string, function>
--- @param method string
--- @vararg any
--- @return boolean
function utils.dispatch(handlers, method, ...)
	local handler = handlers[method]
	if not handler then return false end
	local ok, err = pcall(handler, ...)

	if not ok then
		vim.notify("[todotxt.lsp] handler error (" .. method .. "): " .. tostring(err), vim.log.levels.ERROR)
	end

	return ok
end

return utils
