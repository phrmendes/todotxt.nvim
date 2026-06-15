---
--- Operations on individual todo.txt task lines.
---
--- ==============================================================================
--- @module "todotxt.task"

local parser = require("todotxt.parser")
local utils = require("todotxt.utils")

--- @class Task
local task = {}

--- @enum task.State
--- Task state: TODO (incomplete) or DONE (completed).
task.State = {
	TODO = "todo",
	DONE = "done",
}

--- Check if a task line is completed
--- @param line string
--- @return boolean
task.is_completed = function(line) return parser.parse(line).is_completed end

--- Format a task line to the desired state.
--- @param line string
--- @param state task.State
--- @return string
task.format = function(line, state)
	local parsed = parser.parse(line)

	if state == task.State.DONE then
		parsed.is_completed = true
		parsed.date = parsed.date or {}
		parsed.date.completion = os.date(utils.DATE_FORMAT)
	else
		parsed.is_completed = false
		parsed.date = { creation = parsed.date and parsed.date.creation, completion = nil }
	end

	return parser.build(parsed)
end

return task
