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

--- Returns the 1-indexed start and end of every whole tag on a line.
--- A tag counts only when whitespace (or the line edge) surrounds it, so
--- `+proj` does not match inside `+project` or a word like `a+b`.
--- @param line string
--- @param prefix string
--- @param name string
--- @return { s: integer, e: integer }[]
local function tag_spans(line, prefix, name)
	local spans = {}
	local needle = prefix .. name
	local init = 1

	while true do
		local s, e = line:find(needle, init, true)
		if not s then break end

		local before = s > 1 and line:sub(s - 1, s - 1) or ""
		local after = line:sub(e + 1, e + 1)
		local bounded = (before == "" or before:match("%s")) and (after == "" or after:match("%s"))

		if bounded then table.insert(spans, { s = s, e = e }) end
		init = e + 1
	end

	return spans
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

	for _, t in ipairs(tags) do
		for _, span in ipairs(tag_spans(line, t.prefix, t.name)) do
			if col >= span.s - 1 and col < span.e then
				t.col = span.s
				return t
			end
		end
	end
end

--- Creates a Location for every occurrence of a tag on a line.
--- @param bufname string
--- @param i integer 1-indexed line number
--- @param l string
--- @param prefix string
--- @param name string
--- @return lsp.Location[]
function utils.make_locations(bufname, i, l, prefix, name)
	return vim
		.iter(tag_spans(l, prefix, name))
		:map(
			function(span)
				return {
					uri = bufname,
					range = {
						start = { line = i - 1, character = span.s - 1 },
						["end"] = { line = i - 1, character = span.e },
					},
				}
			end
		)
		:totable()
end

--- Creates a TextEdit for every occurrence of a tag rename on a line.
--- @param i integer 1-indexed line number
--- @param l string
--- @param prefix string
--- @param name string
--- @param new_name string
--- @return lsp.TextEdit[]
function utils.make_text_edits(i, l, prefix, name, new_name)
	return vim
		.iter(tag_spans(l, prefix, name))
		:map(
			function(span)
				return {
					range = {
						start = { line = i - 1, character = span.s - 1 },
						["end"] = { line = i - 1, character = span.e },
					},
					newText = prefix .. new_name,
				}
			end
		)
		:totable()
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
