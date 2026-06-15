---
--- Sorts task lines in the current buffer.
---
--- ==============================================================================
--- @module "todotxt.sorter"

local comparators = require("todotxt.comparators")
local utils = require("todotxt.utils")

--- @class Sorter
local sorter = {}

--- Creates a sort function with a specific comparator
--- @param comparator SortComparator The comparison function to use after completion sorting
sorter.sort = function(comparator)
	utils.sort_table(function(a, b)
		local result = comparators.completion(a, b)
		if result ~= nil then return result end
		return comparator(a, b)
	end)
end

return sorter
