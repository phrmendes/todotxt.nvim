---
--- Sorting comparator functions for todo.txt task lines.
---
--- ==============================================================================
--- @module "todotxt.comparators"

local parser = require("todotxt.parser")
local utils = require("todotxt.utils")

--- @class Comparators
local comparators = {}

--- Sort by completion status, priority, creation date, then text
--- @param a string
--- @param b string
--- @return boolean
comparators.default = function(a, b)
	local pa = utils.get_priority(a)
	local pb = utils.get_priority(b)

	if pa ~= pb then return pa < pb end

	local da = utils.get_creation_date(a)
	local db = utils.get_creation_date(b)

	if da ~= db then return da < db end

	local ta = utils.get_comparable_text(a)
	local tb = utils.get_comparable_text(b)

	return ta < tb
end

--- Compare by completion status (incomplete before completed)
--- @param a string
--- @param b string
--- @return boolean|nil
comparators.completion = function(a, b)
	local ca = parser.parse(a).is_completed
	local cb = parser.parse(b).is_completed

	if ca ~= cb then return cb end

	return nil
end

--- Sort by priority letter (A-Z, unprioritized last)
--- @param a string
--- @param b string
--- @return boolean
comparators.priority = function(a, b)
	local pa = utils.get_priority(a)
	local pb = utils.get_priority(b)

	if pa == pb then return a < b end

	return pa < pb
end

--- Sort by first project tag
--- @param a string
--- @param b string
--- @return boolean
comparators.project = function(a, b)
	local proj_a = vim.F.if_nil(parser.parse(a).projects[1], "~~~")
	local proj_b = vim.F.if_nil(parser.parse(b).projects[1], "~~~")

	if proj_a == proj_b then return a < b end

	return proj_a < proj_b
end

--- Sort by first context tag
--- @param a string
--- @param b string
--- @return boolean
comparators.context = function(a, b)
	local ctx_a = vim.F.if_nil(parser.parse(a).contexts[1], "~~~")
	local ctx_b = vim.F.if_nil(parser.parse(b).contexts[1], "~~~")

	if ctx_a == ctx_b then return a < b end

	return ctx_a < ctx_b
end

--- Sort by due: metadata value
--- @param a string
--- @param b string
--- @return boolean
comparators.due_date = function(a, b)
	local dd_a = parser.parse(a).kv["due"]
	local dd_b = parser.parse(b).kv["due"]

	if dd_a and not dd_b then return true end
	if not dd_a and dd_b then return false end

	if dd_a and dd_b then
		if dd_a == dd_b then return a < b end
		return dd_a < dd_b
	end

	return a < b
end

--- Factory for user-defined metadata comparators
--- @param key string
--- @param sorter string|function "asc", "desc" or custom comparator
--- @return fun(a: string, b: string): boolean
comparators.metadata = function(key, sorter)
	return function(a, b)
		local val_a = utils.get_metadata_value(a, key)
		local val_b = utils.get_metadata_value(b, key)

		if val_a and not val_b then return true end
		if not val_a and val_b then return false end
		if not val_a and not val_b then return a < b end

		if type(sorter) == "function" then
			return sorter(val_a, val_b)
		elseif sorter == "desc" then
			return val_a > val_b
		else
			return val_a < val_b
		end
	end
end

return comparators
