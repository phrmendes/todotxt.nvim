---
--- Regex-based todo.txt parser.
---
--- ==============================================================================
--- @module "todotxt.parser.regex"

local patterns = {
	completed = "^x%s+",
	context = "@%w+",
	date = "%d%d%d%d%-%d%d%-%d%d",
	priority_letter = "%((%a)%)",
	priority_with_space = "%(%a%)%s+",
	project = "%+%w+",
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
	result.priority = line:match(patterns.priority_letter)
	if result.priority then result.priority = result.priority:upper() end

	local stripped = line:gsub(patterns.completed, ""):gsub(patterns.priority_with_space, "")
	local first, second = stripped:match("^%s*(" .. patterns.date .. ")%s+(" .. patterns.date .. ")")

	if not first then first = stripped:match("^%s*(" .. patterns.date .. ")") end

	if result.is_completed then
		result.date.completion = first
		result.date.creation = second
	else
		result.date.creation = first
	end

	result.projects = vim.iter(line:gmatch(patterns.project)):map(function(p) return p:sub(2) end):totable()
	result.contexts = vim.iter(line:gmatch(patterns.context)):map(function(c) return c:sub(2) end):totable()
	vim.iter(line:gmatch("([%w-]+):(%S+)")):each(function(key, value) result.kv[key] = value end)

	result.description = stripped
		:gsub("^%s*" .. patterns.date .. "%s*", "", 1)
		:gsub("^%s*" .. patterns.date .. "%s*", "", 1)
		:match("^%s*(.-)%s*$")

	return result
end

--- @return todotxt.parser.regex
return regex
