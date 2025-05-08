local comparators = require("todotxt.comparators")
local utils = require("todotxt.utils")

local sorter = {}

--- Creates a sort function with a specific comparator
--- @param comparator SortComparator The comparison function to use after completion sorting
--- @return SortFunction sort_func The full sorting function that can be called without arguments
sorter.create = function(comparator)
	return function()
		utils.sort_table(function(a, b)
			local completion_result = comparators.completion(a, b)

			if completion_result ~= nil then return completion_result end

			return comparator(a, b)
		end)
	end
end

return sorter
