---
--- Regex-based todo.txt parser.
---
--- ==============================================================================
--- @module "todotxt.parser.regex"

local patterns = {
	completed = "^x%s+",
	context = "@[^%s]+",
	date = "%d%d%d%d%-%d%d%-%d%d",
	project = "%+[^%s]+",
}

local utils = require("todotxt.parser.utils")

--- @class todotxt.parser.regex
local regex = {}

--- @param line string
--- @return ParsedLine
function regex.parse(line)
	local result = utils.empty()
	if line == "" then return result end

	result.is_completed = line:match(patterns.completed) ~= nil

	-- Only a priority at the start of a task counts, after the optional `x `.
	local stripped = line:gsub(patterns.completed, "")
	stripped = stripped:gsub("^%s*%((%a)%)%s*", function(letter)
		result.priority = letter:upper()
		return ""
	end, 1)
	stripped = stripped:gsub("^%s*", "")
	if result.is_completed and not result.priority then
		stripped = stripped:gsub("^(" .. patterns.date .. ")%s+%((%a)%)%s+", function(date, letter)
			result.priority = letter:upper()
			return date .. " "
		end, 1)
	end

	local first, second = stripped:match("^(" .. patterns.date .. ")%s+(" .. patterns.date .. ")")

	if not first then first = stripped:match("^(" .. patterns.date .. ")") end

	if result.is_completed then
		result.date.completion = first
		result.date.creation = second
	else
		result.date.creation = first
	end

	result.projects = vim.iter(line:gmatch(patterns.project)):map(function(p) return p:sub(2) end):totable()
	result.contexts = vim.iter(line:gmatch(patterns.context)):map(function(c) return c:sub(2) end):totable()
	vim.iter(line:gmatch("([%w-]+):(%S+)")):each(function(key, value)
		result.kv[key] = value
		table.insert(result.kv_pairs, { key, value })
	end)

	result.description =
		stripped:gsub("^" .. patterns.date .. "%s*", "", 1):gsub("^" .. patterns.date .. "%s*", "", 1):match("^%s*(.-)%s*$")

	return result
end

--- @return todotxt.parser.regex
return regex
