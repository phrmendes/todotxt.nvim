local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local utils = dofile("tests/utils.lua")

-- Create child Neovim object
local child = MiniTest.new_child_neovim()

local T = new_set({
	hooks = {
		pre_case = function() 
			child.restart({ '-u', 'scripts/minimal_init.lua' })
			child.lua([[M = require('todotxt')]])
			-- Set up test data
			local todo_dir_path = '/tmp/todotxt.nvim'
			local todo_file_path = todo_dir_path .. '/todo.txt'
			local done_file_path = todo_dir_path .. '/done.txt'
			child.lua(string.format([[
				vim.fn.mkdir('%s', 'p')
				vim.fn.writefile({
					'(A) Test task 1 +project1 @context1 due:2025-12-31',
					'(B) Test task 2 +project2 @context2',
					'(C) Test task 3 +project3 @context3',
					'x 2025-01-01 Test task 4 +project4 @context4',
					'2025-01-01 Test task 5 +project5 @context5',
					'Test task 6',
					'(A) Test task 7',
					'(A)   Multiple spaces   +project   @context',
				}, '%s')
				vim.fn.writefile({}, '%s')
				M.setup({ todotxt = '%s', donetxt = '%s' })
			]], todo_dir_path, todo_file_path, done_file_path, todo_file_path, done_file_path))
		end,
		post_case = function()
			local cwd = child.lua_get("vim.fn.getcwd()")
			local test_files = child.lua_get(string.format("vim.fn.glob(%q, 0, 1)", cwd .. "/test_*"))
			vim.iter(test_files):each(function(file) child.lua(string.format("vim.fn.delete(%q)", file)) end)
		end,
		post_once = function()
			vim.fs.rm("/tmp/todotxt.nvim", { recursive = true, force = true })
			child.stop()
		end,
	},
})

T["toggle_todotxt"] = new_set()

T["toggle_todotxt"]["check file content"] = function()
	local bufnr = utils.toggle_todotxt(child)
	local buffer = utils.get_buffer_content(child, bufnr)

	local expected_lines = {
		"(A) Test task 1 +project1 @context1 due:2025-12-31",
		"(B) Test task 2 +project2 @context2",
		"(C) Test task 3 +project3 @context3",
		"x 2025-01-01 Test task 4 +project4 @context4",
		"2025-01-01 Test task 5 +project5 @context5",
		"Test task 6",
		"(A) Test task 7",
		"(A)   Multiple spaces   +project   @context",
	}

	eq(#buffer, #expected_lines)
	eq(vim.deep_equal(buffer, expected_lines), true)
end

T["toggle_todo_state()"] = new_set()

T["toggle_todo_state()"]["marks completed task as incomplete"] = function()
	local bufnr, win = utils.toggle_todotxt(child)
	utils.toggle_line_todo_state(child, win, 4) -- line 4 is completed

	local buffer = utils.get_buffer_content(child, bufnr)
	eq(buffer[4]:match("^x"), nil)
end

T["toggle_todo_state()"]["marks incomplete task as completed"] = function()
	local bufnr, win = utils.toggle_todotxt(child)
	utils.toggle_line_todo_state(child, win, 5) -- line 5 is incompleted

	local buffer = utils.get_buffer_content(child, bufnr)
	eq(buffer[5]:match("^x %d%d%d%d%-%d%d%-%d%d"), "x " .. os.date("%Y-%m-%d"))
end

T["toggle_todo_state()"]["marks incompleted task with priority as completed"] = function()
	local bufnr, win = utils.toggle_todotxt(child)
	utils.toggle_line_todo_state(child, win, 1) -- line 1 is incompleted with priority

	local buffer = utils.get_buffer_content(child, bufnr)
	eq(buffer[1]:match("^x %(%a%)"), "x (A)")
end

-- Hierarchical project support implementation
-- Based on feature request: https://github.com/todotxt/todo.txt-cli/issues/454
-- Supports sub-projects using dash notation: +foo-frobnizer, +foo-frobnizer-api
T["hierarchical_projects"] = new_set()

T["hierarchical_projects"]["extracts project utilities correctly"] = function()
	-- Test basic extraction
	eq(child.lua_get("require('todotxt.project').extract_projects('Task +project-sub +other')"), { "project-sub", "other" })
	eq(child.lua_get("require('todotxt.project').extract_projects('Task with no projects')"), {})
	eq(child.lua_get("require('todotxt.project').extract_projects('Task +single')"), { "single" })

	-- Test hierarchy parsing
	local hierarchy = child.lua_get("require('todotxt.project').get_project_hierarchy('project-sub-deep')")
	eq(hierarchy.parent, "project")
	eq(hierarchy.sub, { "sub", "deep" })

	hierarchy = child.lua_get("require('todotxt.project').get_project_hierarchy('single')")
	eq(hierarchy.parent, "single")
	eq(hierarchy.sub, {})

	-- Test parent extraction
	eq(child.lua_get("require('todotxt.project').get_parent_projects('Task +foo-bar +baz-qux')"), { "foo", "baz" })
	eq(child.lua_get("require('todotxt.project').get_parent_projects('Task +same +same-sub')"), { "same" })
	eq(child.lua_get("require('todotxt.project').get_parent_projects('Task without projects')"), {})
end

T["hierarchical_projects"]["sorts projects hierarchically"] = function()
	local hierarchical_tasks = {
		"(A) Task in +work-meeting +personal",
		"(B) Task in +work-email", 
		"(C) Task in +work",
		"Task in +personal-shopping",
		"Task in +home-chores-cleaning",
		"Task in +home-chores-laundry", 
		"Task with no project",
		"x 2025-01-01 Completed +home task",
	}

	local expected_sorted = {
		"Task in +home-chores-cleaning",
		"Task in +home-chores-laundry",
		"Task in +personal-shopping",
		"(C) Task in +work",
		"(B) Task in +work-email",
		"(A) Task in +work-meeting +personal",
		"Task with no project",
		"x 2025-01-01 Completed +home task",
	}

	utils.test_sort_function(child, "sort_tasks_by_project", hierarchical_tasks, expected_sorted)
end

return T
