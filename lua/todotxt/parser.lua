---
--- Parser facade — delegates to RegexParser or TSParser based on setup.
--- All callers use parser.parse(line) / parser.build(fields) directly.
---
--- ==============================================================================
--- @module "todotxt.parser"

local parser = {}
local backend

--- @param which string "regex" or "ts"
function parser.use(which)
	if which == "ts" then
		backend = require("todotxt.parser.ts")
		return
	end

	backend = require("todotxt.parser.regex")
end

--- @param line string
--- @return ParsedLine
function parser.parse(line) return backend.parse(line) end

--- @param fields ParsedLine
--- @return string
function parser.build(fields)
	local parts = {}

	if fields.is_completed then
		table.insert(parts, "x")
		if fields.priority then table.insert(parts, "(" .. fields.priority .. ")") end
		if fields.date and fields.date.completion then table.insert(parts, fields.date.completion) end
	else
		if fields.priority then table.insert(parts, "(" .. fields.priority .. ")") end
	end

	if fields.date and fields.date.creation then table.insert(parts, fields.date.creation) end

	if fields.description and fields.description ~= "" then table.insert(parts, fields.description) end

	return table.concat(parts, " ")
end

return parser
