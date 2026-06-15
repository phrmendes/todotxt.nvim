---
--- Priority ring for cycling through todo.txt priority levels.
---
--- ==============================================================================
--- @module "todotxt.priority"

local Priority = {}
Priority.__index = Priority

--- Creates a new priority ring from "A" up to max_priority.
--- @param max_priority string|nil Last priority letter (default "C")
--- @return Priority
function Priority.new(max_priority)
	local last = string.byte((max_priority or "C"):upper())
	local range = vim.iter(vim.fn.range(string.byte("A"), last)):map(string.char):totable()
	local next_map = {}

	vim.iter(range):enumerate():each(function(i, v)
		if i < #range then next_map[v] = range[i + 1] end
	end)

	return setmetatable({
		range = range,
		next_map = next_map,
		first = range[1],
	}, Priority)
end

--- Returns the next priority after the given one, or nil at end of range.
--- Returns the first priority if given nil.
--- @param priority string|nil
--- @return string|nil
function Priority:next(priority)
	if priority then return self.next_map[priority] end
	return self.first
end

--- Returns the full priority range as a list.
--- @return string[]
function Priority:as_list() return self.range end

return Priority
