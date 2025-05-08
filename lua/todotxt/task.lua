local patterns = require("todotxt.patterns")
local utils = require("todotxt.utils")
local task = {}

--- Checks if a task is completed
--- @param line string The line to check
--- @return boolean status Whether the line is completed
task.is_completed = function(line) return line:match(patterns.completed) ~= nil end

--- Format a task as completed
--- @param line string The task line
--- @return string completed_task The formatted completed task
task.format_as_completed = function(line)
	local date = utils.get_current_date()
	local priority, rest = utils.extract_priority(line)

	if priority then return "x " .. priority .. " " .. date .. " " .. rest end

	return "x " .. date .. " " .. line
end

--- Format a task as not completed
--- @param line string The task line
--- @return string uncompleted_task The formatted uncompleted task
task.format_as_uncompleted = function(line)
	if line:match(patterns.completed_with_priority_and_creation_date) then
		local priority = line:match(patterns.priority)
		local uncompleted = line:gsub(patterns.completed_with_priority_and_creation_date, "")

		return priority .. " " .. uncompleted
	end

	local new_line

	if line:match(patterns.completed_with_date) then
		new_line, _ = line:gsub(patterns.completed_with_date, "")

		return new_line
	end

	new_line, _ = line:gsub(patterns.completed, "")

	return new_line
end

return task
