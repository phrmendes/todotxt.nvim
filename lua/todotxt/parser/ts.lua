---
--- Tree-sitter based todo.txt parser.
---
--- The todotxt grammar has no `date` or `priority` children under `done_task`,
--- so completion date and priority on completed lines are extracted via regex.
--- ts.parse strips the `x YYYY-MM-DD ` prefix before parsing the remainder as
--- a `task` node.
---
--- ==============================================================================
--- @module "todotxt.parser.ts"

local patterns = {
	done = "^x%s+%d%d%d%d%-%d%d%-%d%d%s+",
	done_date = "^x%s+(%d%d%d%d%-%d%d%-%d%d)",
}

local utils = require("todotxt.parser.utils")

local buf

local query

--- @return vim.treesitter.Query
local function get_query()
	if not query then
		query = vim.treesitter.query.get("todotxt", "parser")
		if not query then error("failed to load queries/todotxt/parser.scm") end
	end

	return query
end

--- @class todotxt.parser.ts
local ts = {}

--- @param source string
--- @return { name: string, text: string, col_start: integer, col_end: integer }[]
function ts.captures(source)
	if not buf then
		buf = vim.api.nvim_create_buf(false, true)
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { source })

	local ok, ts_parser = pcall(vim.treesitter.get_parser, buf, "todotxt")

	if not ok or not ts_parser then return {} end

	local tree = ts_parser:parse()

	if not tree or vim.tbl_isempty(tree) then return {} end

	local q = get_query()
	local captures = q:iter_captures(tree[1]:root(), buf, 0, -1)
	local results = vim
		.iter(captures)
		:map(function(capture_id, ts_node)
			local _, sc, _, ec = ts_node:range()
			return {
				name = q.captures[capture_id],
				text = vim.treesitter.get_node_text(ts_node, buf),
				col_start = sc,
				col_end = ec,
			}
		end)
		:totable()

	return results
end

--- @param line string
--- @return ParsedLine
function ts.parse(line)
	local result = utils.empty()

	if line == "" then return result end

	local completion_date = nil
	local is_completed = false
	local source = line

	local start_pos, end_pos = line:find(patterns.done)

	if start_pos then
		is_completed = true
		completion_date = line:match(patterns.done_date)
		source = line:sub(end_pos + 1)
	end

	result.is_completed = is_completed
	result.date.completion = completion_date
	result.description = source

	local captures = ts.captures(source)

	vim.iter(captures):each(function(capture)
		if capture.name == "priority" then
			result.priority = capture.text:sub(2, -2)
			return
		end

		if capture.name == "date" and not result.date.creation then
			result.date.creation = capture.text
			return
		end

		if capture.name == "project" then
			table.insert(result.projects, capture.text:sub(2))
			return
		end

		if capture.name == "context" then
			table.insert(result.contexts, capture.text:sub(2))
			return
		end

		local colon = capture.text:find(":")
		if colon then result.kv[capture.text:sub(1, colon - 1)] = capture.text:sub(colon + 1) end
	end)

	table.sort(captures, function(a, b) return a.col_start > b.col_start end)

	result.description = vim
		.iter(captures)
		:fold(source, function(acc, cap) return acc:sub(1, cap.col_start) .. acc:sub(cap.col_end + 1) end)
		:gsub("%s+", " ")
		:match("^%s*(.-)%s*$")

	return result
end

--- @return todotxt.parser.ts
return ts
