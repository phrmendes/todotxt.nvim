local patterns = require("todotxt.patterns")
local project_utils = require("todotxt.project")
local task = require("todotxt.task")
local utils = require("todotxt.utils")

local comparators = {}

--- Default comparator that sorts by completion status, priority, and text
--- @param a string First task line
--- @param b string Second task line
--- @return boolean
comparators.default = function(a, b)
	local priority_a = utils.priority_letter(a)
	local priority_b = utils.priority_letter(b)

	if priority_a ~= priority_b then return priority_a < priority_b end

	local date_a = utils.creation_date(a)
	local date_b = utils.creation_date(b)

	if date_a ~= date_b then return date_a < date_b end

	local text_a = utils.comparable_text(a)
	local text_b = utils.comparable_text(b)

	return text_a < text_b
end

--- Comparator that sorts by completion status (incomplete first).
--- @param a string First task line
--- @param b string Second task line
--- @return boolean|nil It returns true if a is incomplete, false if b is incomplete, or nil if both are completed.
comparators.completion = function(a, b)
	local a_completed = task.is_completed(a)
	local b_completed = task.is_completed(b)

	if a_completed ~= b_completed then return not a_completed end

	return nil
end

--- Comparator that sorts by priority
--- @param a string First task line
--- @param b string Second task line
--- @return boolean
comparators.priority = function(a, b)
	local priority_a = utils.priority_letter(a)
	local priority_b = utils.priority_letter(b)

	if priority_a == priority_b then return a < b end

	return priority_a < priority_b
end

--- Comparator that sorts by project hierarchically
--- @param a string First task line
--- @param b string Second task line
--- @return boolean
comparators.project = function(a, b)
	-- Get first parent project for primary sorting
	local parent_a = project_utils.get_first_parent(a) or "~~~"
	local parent_b = project_utils.get_first_parent(b) or "~~~"

	-- If parents are different, sort by parent
	if parent_a ~= parent_b then return parent_a < parent_b end

	-- If parents are the same, sort by full sub-project path
	local sub_a = project_utils.get_first_subproject_path(a) or ""
	local sub_b = project_utils.get_first_subproject_path(b) or ""

	-- If sub-paths are different, sort by sub-path
	if sub_a ~= sub_b then return sub_a < sub_b end

	-- Within same project hierarchy, sort by priority then text
	local priority_a = utils.priority_letter(a)
	local priority_b = utils.priority_letter(b)

	if priority_a ~= priority_b then return priority_a < priority_b end

	-- Final fallback to task text comparison
	return a < b
end

--- Comparator that sorts by context
--- @param a string First task line
--- @param b string Second task line
--- @return boolean
comparators.context = function(a, b)
	local context_a = a:match(patterns.context) or "~~~"
	local context_b = b:match(patterns.context) or "~~~"

	if context_a == context_b then return a < b end

	return context_a < context_b
end

--- Comparator that sorts by due date
--- @param a string First task line
--- @param b string Second task line
--- @return boolean
comparators.due_date = function(a, b)
	local due_date_a = a:match(patterns.due_date)
	local due_date_b = b:match(patterns.due_date)

	if due_date_a and not due_date_b then return true end
	if not due_date_a and due_date_b then return false end

	if due_date_a and due_date_b then
		if due_date_a == due_date_b then return a < b end

		return due_date_a < due_date_b
	end

	return a < b
end

return comparators
