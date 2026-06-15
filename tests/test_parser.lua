local test = require("mini.test")
local utils = dofile("tests/utils.lua")
local new_set, eq = test.new_set, test.expect.equality

local child, T = utils.new_child_set()

T["parse_line"] = test.new_set()

T["parse_line"]["incomplete task with priority and date"] = function()
	local result = child.lua("return require('todotxt.parser').parse('(A) 2025-06-13 Task description')")
	eq(type(result), "table")
	eq(result.is_completed, false)
	eq(result.priority, "A")
	eq(result.date.creation, "2025-06-13")
	eq(result.description, "Task description")
	eq(result.projects, {})
	eq(result.contexts, {})
	eq(result.kv, {})
end

T["parse_line"]["completed task with priority and dual dates"] = function()
	local result = child.lua("return require('todotxt.parser').parse('x (A) 2025-06-13 2025-01-01 Completed task')")
	eq(result.is_completed, true)
	eq(result.priority, "A")
	eq(result.date.completion, "2025-06-13")
	eq(result.date.creation, "2025-01-01")
	eq(result.description, "Completed task")
end

T["parse_line"]["completed task without priority"] = function()
	local result = child.lua("return require('todotxt.parser').parse('x 2025-06-13 Simple completed')")
	eq(result.is_completed, true)
	eq(result.priority, nil)
	eq(result.date.completion, "2025-06-13")
	eq(result.description, "Simple completed")
end

T["parse_line"]["task with projects and contexts"] = function()
	local result = child.lua("return require('todotxt.parser').parse('(B) Task +work +personal @phone @home')")
	eq(result.is_completed, false)
	eq(result.priority, "B")
	eq(result.projects, { "work", "personal" })
	eq(result.contexts, { "phone", "home" })
	eq(result.description, "Task +work +personal @phone @home")
end

T["parse_line"]["task with key-value metadata"] = function()
	local result = child.lua("return require('todotxt.parser').parse('Task due:2025-12-31 rec:+1w')")
	eq(result.kv.due, "2025-12-31")
	eq(result.kv.rec, "+1w")
	eq(result.description, "Task due:2025-12-31 rec:+1w")
end

T["parse_line"]["task without any formatting"] = function()
	local result = child.lua("return require('todotxt.parser').parse('Just a plain task')")
	eq(result.is_completed, false)
	eq(result.priority, nil)
	eq(result.description, "Just a plain task")
end

T["parse_line"]["empty line"] = function()
	local result = child.lua("return require('todotxt.parser').parse('')")
	eq(type(result), "table")
	eq(result.description, "")
	eq(result.is_completed, false)
end

T["parse_line"]["regex fallback for malformed priority"] = function()
	local result = child.lua("return require('todotxt.parser').parse('(1) Numeric priority task')")
	eq(type(result), "table")
	-- regex fallback should extract description, may or may not extract priority
	eq(type(result.description), "string")
end

T["parse_line"]["regex fallback for invalid date"] = function()
	local result = child.lua("return require('todotxt.parser').parse('x 2025-13-01 Invalid month task')")
	eq(type(result), "table")
	eq(result.is_completed, true)
end

T["construct"] = test.new_set()

T["construct"]["build_line from parsed fields"] = function()
	local result = child.lua([[
		local parser = require('todotxt.parser')
		return parser.build({
			is_completed = false,
			priority = "A",
			date = { creation = "2025-06-13", completion = nil },
			description = "Test task +work @phone due:2025-12-31",
		})
	]])
	eq(result, "(A) 2025-06-13 Test task +work @phone due:2025-12-31")
end

T["construct"]["build_line completed task"] = function()
	local result = child.lua([[
		local parser = require('todotxt.parser')
		return parser.build({
			is_completed = true,
			priority = "B",
			date = { creation = "2025-01-01", completion = "2025-06-13" },
			description = "Done task",
		})
	]])
	eq(result, "x (B) 2025-06-13 2025-01-01 Done task")
end

T["construct"]["build_line minimal task"] = function()
	local result = child.lua("return require('todotxt.parser').build({ description = 'Minimal' })")
	eq(result, "Minimal")
end

T["construct"]["build_line roundtrip"] = function()
	local original = "x (A) 2025-06-13 2025-01-01 Task +proj @ctx due:2025-12-31"
	local result = child.lua(string.format([[
		local parser = require('todotxt.parser')
		local parsed = parser.parse(%q)
		return parser.build(parsed)
	]], original))
	eq(result, original)
end

return T
