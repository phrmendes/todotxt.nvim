---
--- Shared parser utilities.
---
--- ==============================================================================
--- @module "todotxt.parser.utils"

local utils = {}

--- @return ParsedLine
function utils.empty()
	return {
		is_completed = false,
		priority = nil,
		date = { creation = nil, completion = nil },
		projects = {},
		contexts = {},
		kv = {},
		kv_pairs = {},
		description = "",
	}
end

return utils
