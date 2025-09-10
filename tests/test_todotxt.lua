local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local utils = dofile("tests/utils.lua")

-- Create child Neovim object
local child = MiniTest.new_child_neovim()

local T = new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "scripts/minimal_init.lua" })
			child.lua([[M = require('todotxt')]])
			-- Set up test data
			local todo_dir_path = "/tmp/todotxt.nvim"
			local todo_file_path = todo_dir_path .. "/todo.txt"
			local done_file_path = todo_dir_path .. "/done.txt"
			child.lua(string.format(
				[[
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
			]],
				todo_dir_path,
				todo_file_path,
				done_file_path,
				todo_file_path,
				done_file_path
			))
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
	eq(
		child.lua_get("require('todotxt.project').extract_projects('Task +project-sub +other')"),
		{ "project-sub", "other" }
	)
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

T["move_done_tasks"] = new_set()

T["move_done_tasks"]["no w12 warning with open buffer"] = function()
	-- Setup: Create test data with completed and uncompleted tasks
	local bufnr, todo_path, done_path = utils.setup_temp_files(child, {
		"(A) Uncompleted task 1 +project @context",
		"x 2025-01-01 Completed task 1 +project @context",
		"(B) Uncompleted task 2",
		"x 2025-01-02 Completed task 2",
		"Template task h:1", -- Hidden task that should be preserved
	})

	-- Clear any existing warning messages
	child.api.nvim_set_vvar("warningmsg", "")

	-- Execute move_done_tasks
	child.lua("M.move_done_tasks()")

	-- Check if buffer is modified (should be false after our sync)
	local buffer_modified = child.api.nvim_get_option_value("modified", { buf = bufnr })
	eq(buffer_modified, false)

	-- Try to write the buffer with force - this should NOT trigger W12 warning
	local write_result = child.api.nvim_exec2("write!", { output = true })
	local warning_msg = child.api.nvim_get_vvar("warningmsg")

	-- Assert no W12 warning occurred
	eq(warning_msg, "")
	eq(write_result.output:match("W12"), nil)

	-- Verify file contents are correct after move (before adding new task)
	local remaining_todo = child.lua_get(string.format("vim.fn.readfile(%q)", todo_path))
	local done_contents = child.lua_get(string.format("vim.fn.readfile(%q)", done_path))

	-- Should have 2 uncompleted tasks + 1 hidden task remaining in todo
	eq(#remaining_todo, 3)
	eq(remaining_todo[1], "(A) Uncompleted task 1 +project @context")
	eq(remaining_todo[2], "(B) Uncompleted task 2")
	eq(remaining_todo[3], "Template task h:1")

	-- Should have 2 completed tasks moved to done
	eq(#done_contents, 2)
	eq(done_contents[1], "x 2025-01-01 Completed task 1 +project @context")
	eq(done_contents[2], "x 2025-01-02 Completed task 2")

	-- Test subsequent modification and write to ensure sync is maintained
	child.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "New task added after move" })
	local write_result2 = child.api.nvim_exec2("write", { output = true })
	local warning_msg2 = child.api.nvim_get_vvar("warningmsg")

	-- Should still not have W12 warnings
	eq(warning_msg2, "")
	eq(write_result2.output:match("W12"), nil)

	utils.cleanup_files(child, todo_path, done_path)
end

T["move_done_tasks"]["hidden tasks preserved on move"] = function()
	-- Setup with hide_tasks enabled (default)
	local bufnr, todo_path, done_path = utils.setup_temp_files(child, {
		"(A) Regular task +work",
		"x 2025-01-01 Done task +work",
		"Hidden metadata task h:1",
		"Another hidden task h:2",
		"x 2025-01-02 Done hidden task +secret h:1",
	})

	-- Move done tasks
	child.lua("M.move_done_tasks()")

	-- Verify hidden tasks are preserved in todo.txt
	local remaining_todo = child.lua_get(string.format("vim.fn.readfile(%q)", todo_path))
	local done_contents = child.lua_get(string.format("vim.fn.readfile(%q)", done_path))

	-- Todo should have: regular task + both hidden tasks (including completed hidden)
	eq(#remaining_todo, 4)
	eq(remaining_todo[1], "(A) Regular task +work")
	eq(remaining_todo[2], "Hidden metadata task h:1")
	eq(remaining_todo[3], "Another hidden task h:2")
	eq(remaining_todo[4], "x 2025-01-02 Done hidden task +secret h:1")

	-- Done should only have the non-hidden completed task
	eq(#done_contents, 1)
	eq(done_contents[1], "x 2025-01-01 Done task +work")

	utils.cleanup_files(child, todo_path, done_path)
end

T["move_done_tasks"]["works when no buffers open"] = function()
	-- Setup files but don't open any buffers
	local todo_path, done_path = utils.create_temp_file_paths(child)
	utils.create_test_todo_file(child, todo_path, {
		"(A) Task 1",
		"x 2025-01-01 Done task 1",
		"Task 2",
	})

	-- Setup plugin without opening buffers
	child.lua(string.format("M.setup({ todotxt = %q, donetxt = %q })", todo_path, done_path))

	-- Move done tasks
	child.lua("M.move_done_tasks()")

	-- Verify results
	local remaining_todo = child.lua_get(string.format("vim.fn.readfile(%q)", todo_path))
	local done_contents = child.lua_get(string.format("vim.fn.readfile(%q)", done_path))

	eq(#remaining_todo, 2)
	eq(remaining_todo[1], "(A) Task 1")
	eq(remaining_todo[2], "Task 2")

	eq(#done_contents, 1)
	eq(done_contents[1], "x 2025-01-01 Done task 1")

	utils.cleanup_files(child, todo_path, done_path)
end

return T
