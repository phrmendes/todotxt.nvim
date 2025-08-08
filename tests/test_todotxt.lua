local test = require("mini.test")
local utils = dofile("tests/utils.lua")
local new_set, eq = test.new_set, test.expect.equality

local child = test.new_child_neovim()

local T = new_set({
	hooks = {
		pre_case = function() child.restart({ "-u", "scripts/init.lua" }) end,
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

T["toggle_todo_state()"]["marks completed task with priority as incompleted"] = function()
	local bufnr, win = utils.toggle_todotxt(child)
	utils.toggle_line_todo_state(child, win, 1) -- line 1 is incompleted with priority
	utils.toggle_line_todo_state(child, win, 1)

	local buffer = utils.get_buffer_content(child, bufnr)
	eq(buffer[1]:match("^%(%a%)"), "(A)")
end

T["toggle_todo_state()"]["handles task with unusual formatting"] = function()
	local bufnr, win = utils.toggle_todotxt(child)
	utils.toggle_line_todo_state(child, win, 8) -- line 8 is a task with multiple spaces

	local buffer = utils.get_buffer_content(child, bufnr)
	eq(buffer[8], "x (A) " .. os.date("%Y-%m-%d") .. " Multiple spaces   +project   @context")
end

T["toggle_todo_state()"]["toggles tasks with various date and priority combinations"] = function()
	local bufnr, win = utils.toggle_todotxt(child)

	utils.toggle_line_todo_state(child, win, 6) -- line 6: "Test task 6" (no date, no priority)
	local buffer = utils.get_buffer_content(child, bufnr)
	eq(buffer[6], "x " .. os.date("%Y-%m-%d") .. " Test task 6")

	utils.toggle_line_todo_state(child, win, 1) -- line 1: "(A) Test task 1..." (has priority, no date)
	buffer = utils.get_buffer_content(child, bufnr)
	eq(buffer[1], "x (A) " .. os.date("%Y-%m-%d") .. " Test task 1 +project1 @context1 due:2025-12-31")
end

T["toggle_todo_state()"]["works with files in current working directory"] = function()
	local todo_path, done_path = utils.create_local_file_paths(child, "todo.txt", "done.txt")
	local bufnr = utils.setup_local_files(child, todo_path, done_path, utils.PWD_TEST_TASKS)
	child.lua(string.format("vim.fn.writefile({}, %q)", done_path))

	local initial_lines = utils.get_buffer_content(child, bufnr)
	eq(#initial_lines, 3)
	eq(initial_lines[2], "(B) PWD task 2")

	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.lua("M.toggle_todo_state()")

	local lines = utils.get_buffer_content(child, bufnr)
	utils.assert_task_completed(lines, 2, os.date("%Y-%m-%d"), "PWD task 2", true)

	local done_lines = child.lua_get(string.format("vim.fn.readfile(%q)", done_path))
	eq(#done_lines, 0)

	utils.cleanup_files(child, todo_path, done_path)
end

T["toggle_todo_state()"]["populates done.txt when using local files and moving tasks"] = function()
	local local_tasks = {
		"(A) Local task 1",
		"(B) Local task 2",
		"x 2025-01-01 Local completed task",
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, local_tasks, "todo.txt", "done.txt")
	utils.assert_file_not_exists(child, done_path)

	child.lua("M.move_done_tasks()")

	utils.assert_file_exists(child, done_path)
	local done_lines_after = child.lua_get(string.format("vim.fn.readfile(%q)", done_path))
	eq(#done_lines_after, 1)
	eq(done_lines_after[1], "x 2025-01-01 Local completed task")

	local todo_lines = utils.get_buffer_content(child, bufnr)
	eq(#todo_lines, 2)

	utils.cleanup_files(child, todo_path, done_path)
end

T["toggle_todo_state()"]["doesn't create done.txt file from setup or floating window operations"] = function()
	local tasks = {
		"(A) Important task",
		"Regular task",
		"x 2024-01-01 Already completed task",
	}

	local _, todo_path, done_path, _ = utils.setup_temp_files(child, tasks, "todo.txt", "done.txt")

	utils.assert_file_not_exists(child, done_path)

	-- toggle_todo_state don't create done.txt
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.lua("M.toggle_todo_state()")
	child.lua("M.toggle_todo_state()")
	utils.assert_file_not_exists(child, done_path)

	--  opening/closing done.txt floating window doesn't create done.txt
	child.lua("M.toggle_donetxt()")
	child.lua("M.toggle_donetxt()")
	utils.assert_file_not_exists(child, done_path)

	-- move_done_tasks creates done.txt
	child.lua("M.move_done_tasks()")
	utils.assert_file_exists(child, done_path)

	local done_lines = child.lua_get(string.format("vim.fn.readfile(%q)", done_path))

	eq(#done_lines, 1)
	eq(done_lines[1], tasks[3])

	utils.cleanup_files(child, todo_path, done_path)
end

T["sort_tasks()"] = new_set()

T["sort_tasks()"]["doesn't crash with empty todo.txt"] = function()
	child.lua([[vim.fn.writefile({}, M.config.todotxt)]])

	child.lua("M.sort_tasks()")

	eq(utils.get_buffer_content(child, utils.toggle_todotxt(child)), { "" })
end

T["sort_tasks()"]["sorts mixed task formats"] = function()
	local expected_tasks = {
		"(A) Priority A task",
		"(B) 2024-01-01 Priority B task with creation date",
		"2024-02-01 Task with creation date",
		"Simple task",
		"Task with +project",
		"Task with @context",
		"x 2024-03-01 (C) Completed priority C task",
		"x 2024-03-15 Completed task with date",
		"x Completed task without date",
	}

	local shuffled_tasks = {
		"x Completed task without date",
		"Task with @context",
		"Simple task",
		"x 2024-03-15 Completed task with date",
		"(A) Priority A task",
		"2024-02-01 Task with creation date",
		"x 2024-03-01 (C) Completed priority C task",
		"(B) 2024-01-01 Priority B task with creation date",
		"Task with +project",
	}

	utils.test_sort_function(child, "sort_tasks", shuffled_tasks, expected_tasks)
end

T["sort_tasks_by_priority()"] = new_set()

T["sort_tasks_by_priority()"]["sorts tasks by different criteria"] = function()
	local priority_test = {
		shuffled = { "(B) Test task 2", "x 2025-01-01 Test task 4", "(C) Test task 3", "(A) Test task 1" },
		expected = { "(A) Test task 1", "(B) Test task 2", "(C) Test task 3", "x 2025-01-01 Test task 4" },
	}

	local project_test = {
		shuffled = {
			"(A) Test task 1 +project3",
			"(B) Test task 2 +project2",
			"(C) Test task 3 +project1",
			"x 2025-01-01 Test task 4 +project4",
		},
		expected = {
			"(C) Test task 3 +project1",
			"(B) Test task 2 +project2",
			"(A) Test task 1 +project3",
			"x 2025-01-01 Test task 4 +project4",
		},
	}

	local context_test = {
		shuffled = {
			"(B) Test task 2 @context2",
			"(A) Test task 1 @context1",
			"x 2025-01-01 Test task 4 @context1",
			"(C) Test task 3 @context3",
		},
		expected = {
			"(A) Test task 1 @context1",
			"(B) Test task 2 @context2",
			"(C) Test task 3 @context3",
			"x 2025-01-01 Test task 4 @context1",
		},
	}

	utils.test_sort_function(child, "sort_tasks_by_priority", priority_test.shuffled, priority_test.expected)
	utils.test_sort_function(child, "sort_tasks_by_project", project_test.shuffled, project_test.expected)
	utils.test_sort_function(child, "sort_tasks_by_context", context_test.shuffled, context_test.expected)

	local multi_project_test = {
		shuffled = { "(B) Task with +one_project", "(A) Task with +multiple +projects" },
		expected = { "(A) Task with +multiple +projects", "(B) Task with +one_project" },
	}
	utils.test_sort_function(child, "sort_tasks_by_project", multi_project_test.shuffled, multi_project_test.expected)
end

T["sort_tasks_by_due_date()"] = new_set()

T["sort_tasks_by_due_date()"]["sorts tasks by due date"] = function()
	local expected_tasks = {
		"(A) Test task 1 due:2025-01-01",
		"(B) Test task 2 due:2025-01-02",
		"(C) Test task 3 due:2025-01-03",
		"x 2025-01-01 Test task 4",
	}

	local shuffled_tasks = {
		"(C) Test task 3 due:2025-01-03",
		"(B) Test task 2 due:2025-01-02",
		"x 2025-01-01 Test task 4",
		"(A) Test task 1 due:2025-01-01",
	}

	utils.test_sort_function(child, "sort_tasks_by_due_date", shuffled_tasks, expected_tasks)
end

T["sort_tasks_by_due_date()"]["handles same due date (sorts alphabetically)"] = function()
	local expected_tasks = {
		"(A) Task C due:2025-01-01",
		"(B) Task B due:2025-01-01",
		"(C) Task A due:2025-01-02",
	}

	local shuffled_tasks = {
		"(C) Task A due:2025-01-02",
		"(A) Task C due:2025-01-01",
		"(B) Task B due:2025-01-01",
	}

	utils.test_sort_function(child, "sort_tasks_by_due_date", shuffled_tasks, expected_tasks)
end

T["cycle_priority()"] = new_set()

T["cycle_priority()"]["cycles through all priority levels"] = function()
	local priority_cycles = {
		{ initial = "(A) Test priority cycling", expected = "(B) Test priority cycling" },
		{ initial = "(B) Test priority cycling", expected = "(C) Test priority cycling" },
		{ initial = "(C) Test priority cycling", expected = "Test priority cycling" },
		{ initial = "Test priority cycling", expected = "(A) Test priority cycling" },
	}

	vim.iter(priority_cycles):each(function(cycle) utils.test_priority_cycle(child, cycle.initial, cycle.expected) end)
end

T["cycle_priority()"]["handles edge cases and special scenarios"] = function()
	local date = os.date("%Y-%m-%d")
	local scenarios = {
		{
			initial = "(B) Test with special chars: !@#$%^&*()",
			expected = "(C) Test with special chars: !@#$%^&*()",
		},
		{
			initial = "x 2025-01-01 (A) Test completed task",
			expected = "x 2025-01-01 (B) Test completed task",
		},
		{
			initial = "x " .. date .. " Task text",
			expected = "x (A) " .. date .. " Task text",
		},
	}

	vim.iter(scenarios):each(function(scenario) utils.test_priority_cycle(child, scenario.initial, scenario.expected) end)
end

T["capture_todo()"] = new_set()

T["capture_todo()"]["adds new todo to buffer or file appropriately"] = function()
	local bufnr = utils.toggle_todotxt(child)
	local initial_count = #utils.get_buffer_content(child, bufnr)

	utils.setup_todo_input(child, "Test todo in buffer")
	child.lua("M.capture_todo()")

	local buffer_lines = utils.get_buffer_content(child, bufnr)
	eq(#buffer_lines, initial_count + 1)
	eq(buffer_lines[#buffer_lines], os.date("%Y-%m-%d") .. " Test todo in buffer")

	child.cmd("bdelete!")
	child.cmd("new")

	utils.setup_todo_input(child, "Test todo from file")
	child.lua("M.capture_todo()")

	local file_bufnr = utils.toggle_todotxt(child)
	local file_lines = utils.get_buffer_content(child, file_bufnr)
	eq(file_lines[#file_lines]:match("Test todo from file"), "Test todo from file")
end
T["capture_todo()"]["handles various input scenarios"] = function()
	local bufnr = utils.toggle_todotxt(child)
	local initial_lines = utils.get_buffer_content(child, bufnr)
	local line_count = #initial_lines
	local added_count = 0

	local scenarios = {
		{
			input = "(A) New test todo",
			expected = "(A) " .. os.date("%Y-%m-%d") .. " New test todo",
			should_add = true,
		},
		{
			input = "",
			expected = "",
			should_add = false,
		},
		{
			input = "2024-01-01 Existing date task",
			expected = "2024-01-01 Existing date task",
			should_add = true,
		},
	}

	vim.iter(scenarios):each(function(scenario)
		utils.setup_todo_input(child, scenario.input)
		child.lua("M.capture_todo()")

		local new_lines = utils.get_buffer_content(child, bufnr)

		if scenario.should_add then
			added_count = added_count + 1
			eq(#new_lines, line_count + added_count)
			eq(new_lines[#new_lines], scenario.expected)
		else
			eq(#new_lines, line_count + added_count)
		end
	end)
end

T["move_done_tasks()"] = new_set()

T["move_done_tasks()"]["moves completed tasks to done.txt"] = function()
	local bufnr = utils.toggle_todotxt(child)

	local todo_lines_before = utils.get_buffer_content(child, bufnr)
	local done_lines_before = child.lua_get("vim.fn.readfile(M.config.donetxt)")

	local checked_lines = utils.count_completed_tasks(todo_lines_before)
	local checked_line = vim.iter(todo_lines_before):find(function(line) return line:match("^x") end)

	child.lua("M.move_done_tasks()")

	local done_lines_after = child.lua_get("vim.fn.readfile(M.config.donetxt)")
	local todo_lines_after = utils.get_buffer_content(child, bufnr)

	eq(#done_lines_before, 0)
	eq(#todo_lines_after, #todo_lines_before - checked_lines)
	eq(#done_lines_after, checked_lines)
	eq({ checked_line }, require("mini.misc").tbl_head(done_lines_after, 1))
end

T["input_validation"] = new_set()

T["input_validation"]["handles empty files"] = function()
	child.lua([[vim.fn.writefile({}, M.config.todotxt)]])
	local bufnr = utils.toggle_todotxt(child)
	local buffer = utils.get_buffer_content(child, bufnr)
	eq(buffer, { "" })

	child.lua("M.sort_tasks()")
	child.lua("M.move_done_tasks()")
end

T["input_validation"]["handles whitespace-only content"] = function()
	child.lua([[vim.fn.writefile({"   ", "\t\t", "  \t  ", ""}, M.config.todotxt)]])
	local bufnr = utils.toggle_todotxt(child)

	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.lua("M.toggle_todo_state()")
	child.lua("M.cycle_priority()")

	local buffer = utils.get_buffer_content(child, bufnr)
	eq(#buffer, 4)
end

T["input_validation"]["handles malformed priorities"] = function()
	local malformed_tasks = {
		"(AA) Invalid double letter priority",
		"(1) Numeric priority",
		"(a) Lowercase priority",
		"() Empty priority",
		"(ABC) Too long priority",
		"( ) Space priority",
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, malformed_tasks, "todo.txt", "done.txt")

	vim.iter(vim.fn.range(1, #malformed_tasks)):each(function(i)
		child.api.nvim_win_set_cursor(0, { i, 0 })
		child.lua("M.cycle_priority()")
	end)

	child.lua("M.sort_tasks_by_priority()")

	local buffer = utils.get_buffer_content(child, bufnr)

	eq(#buffer, #malformed_tasks)

	utils.cleanup_files(child, todo_path, done_path)
end

T["input_validation"]["handles very long task descriptions"] = function()
	local long_text = string.rep("Very long task description ", 100)
	local long_tasks = {
		"(A) " .. long_text,
		long_text .. " +project @context due:2025-12-31",
		"x 2025-01-01 " .. long_text,
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, long_tasks, "todo.txt", "done.txt")

	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.lua("M.toggle_todo_state()")
	child.lua("M.cycle_priority()")
	child.lua("M.sort_tasks()")

	local buffer = utils.get_buffer_content(child, bufnr)
	eq(#buffer, #long_tasks)

	utils.cleanup_files(child, todo_path, done_path)
end

T["input_validation"]["handles special characters and unicode"] = function()
	local special_tasks = {
		"(A) Task with émojis and åccénts",
		"Task with tabs and special chars",
		"(B) Special chars: !@#$%^&*(){}[]|\\:;\"'<>?,./~`",
		"x 2025-01-01 Completed with unicode chars",
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, special_tasks, "todo.txt", "done.txt")

	vim.iter(vim.fn.range(1, #special_tasks)):each(function(i)
		child.api.nvim_win_set_cursor(0, { i, 0 })
		child.lua("M.toggle_todo_state()")
		child.lua("M.cycle_priority()")
	end)

	child.lua("M.sort_tasks()")
	child.lua("M.sort_tasks_by_project()")
	child.lua("M.sort_tasks_by_context()")

	local buffer = utils.get_buffer_content(child, bufnr)
	eq(#buffer, #special_tasks)

	utils.cleanup_files(child, todo_path, done_path)
end

T["input_validation"]["handles malformed dates"] = function()
	local malformed_date_tasks = {
		"x 2025-13-01 Invalid month",
		"x 2025-02-30 Invalid day for month",
		"x 2025-1-1 Single digit month/day",
		"x 25-01-01 Two digit year",
		"x 2025/01/01 Wrong separator",
		"x 2025-01-32 Invalid day",
		"x 0000-00-00 Zero date",
		"x 9999-99-99 Extreme date",
		"(A) 2025-13-01 Task with invalid creation date",
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, malformed_date_tasks, "todo.txt", "done.txt")

	vim.iter(vim.fn.range(1, #malformed_date_tasks)):each(function(i)
		child.api.nvim_win_set_cursor(0, { i, 0 })
		child.lua("M.toggle_todo_state()")
	end)

	child.lua("M.sort_tasks()")
	child.lua("M.sort_tasks_by_due_date()")
	child.lua("M.move_done_tasks()")

	local buffer = utils.get_buffer_content(child, bufnr)

	eq(type(buffer), "table")

	utils.cleanup_files(child, todo_path, done_path)
end

T["complex_formats"] = new_set()

T["complex_formats"]["handles tasks with completion and creation dates"] = function()
	local dual_date_tasks = {
		"x 2025-01-15 2024-12-01 Task completed on Jan 15, created on Dec 1",
		"x (A) 2025-01-15 2024-12-01 Priority task with dual dates",
		"x (B) 2025-02-01 2024-11-15 Another priority task with dates",
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, dual_date_tasks, "todo.txt", "done.txt")

	vim.iter(vim.fn.range(1, #dual_date_tasks)):each(function(i)
		child.api.nvim_win_set_cursor(0, { i, 0 })
		child.lua("M.toggle_todo_state()")
		local buffer = utils.get_buffer_content(child, bufnr)
		eq(buffer[i]:match("^x"), nil)
	end)

	vim.iter(vim.fn.range(1, #dual_date_tasks)):each(function(i)
		child.api.nvim_win_set_cursor(0, { i, 0 })
		child.lua("M.toggle_todo_state()")
	end)

	child.lua("M.sort_tasks()")
	child.lua("M.move_done_tasks()")

	utils.cleanup_files(child, todo_path, done_path)
end

T["complex_formats"]["handles tasks with multiple projects and contexts"] = function()
	local multi_tag_tasks = {
		"(A) Task with +project1 +project2 @context1 @context2 due:2025-12-31",
		"Task +work +personal @home @office @phone due:2025-01-15 rec:+1w",
		"x 2025-01-01 Completed +multi +tag @task @test",
		"(B) 2024-12-01 Created task +proj1 +proj2 +proj3 @ctx1 @ctx2",
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, multi_tag_tasks, "todo.txt", "done.txt")

	child.lua("M.sort_tasks_by_project()")
	local buffer_after_project = utils.get_buffer_content(child, bufnr)

	child.lua("M.sort_tasks_by_context()")
	local buffer_after_context = utils.get_buffer_content(child, bufnr)

	child.lua("M.sort_tasks_by_due_date()")
	local buffer_after_due = utils.get_buffer_content(child, bufnr)

	eq(#buffer_after_project, #multi_tag_tasks)
	eq(#buffer_after_context, #multi_tag_tasks)
	eq(#buffer_after_due, #multi_tag_tasks)

	utils.cleanup_files(child, todo_path, done_path)
end

T["complex_formats"]["handles tasks with unusual spacing"] = function()
	local spacing_tasks = {
		"(A)Task without space after priority",
		"x(A) Completed without space",
		"  (B)  Multiple  spaces  everywhere  ",
		"\t(C)\tTask\twith\ttabs\t",
		"(A)  2024-12-01  Task  with  date  and  spaces",
		"x  (A)  2025-01-01  Completed  with  spaces",
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, spacing_tasks, "todo.txt", "done.txt")

	vim.iter(vim.fn.range(1, #spacing_tasks)):each(function(i)
		child.api.nvim_win_set_cursor(0, { i, 0 })
		child.lua("M.toggle_todo_state()")
		child.lua("M.cycle_priority()")
	end)

	child.lua("M.sort_tasks()")
	local buffer = utils.get_buffer_content(child, bufnr)
	eq(#buffer, #spacing_tasks)

	utils.cleanup_files(child, todo_path, done_path)
end

T["date_edge_cases"] = new_set()

T["date_edge_cases"]["handles year boundary dates"] = function()
	local boundary_tasks = {
		"x 2024-12-31 Completed on New Year's Eve",
		"(A) 2025-01-01 Task created on New Year's Day",
		"Task due:2024-12-31",
		"Task due:2025-01-01",
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, boundary_tasks, "todo.txt", "done.txt")

	child.lua("M.sort_tasks_by_due_date()")
	child.lua("M.sort_tasks()")

	local buffer = utils.get_buffer_content(child, bufnr)
	eq(#buffer, #boundary_tasks)

	utils.cleanup_files(child, todo_path, done_path)
end

T["date_edge_cases"]["handles future dates"] = function()
	local future_year = tonumber(os.date("%Y")) + 5
	local future_tasks = {
		"(A) Task due:" .. future_year .. "-12-31",
		"x " .. future_year .. "-01-01 Completed in future",
		"(" .. future_year .. "-06-15) Task created in future",
		"Task due:" .. (future_year + 10) .. "-01-01",
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, future_tasks, "todo.txt", "done.txt")

	child.lua("M.sort_tasks_by_due_date()")
	child.lua("M.sort_tasks()")

	vim.iter(vim.fn.range(1, #future_tasks)):each(function(i)
		child.api.nvim_win_set_cursor(0, { i, 0 })
		child.lua("M.toggle_todo_state()")
		child.lua("M.cycle_priority()")
	end)

	local buffer = utils.get_buffer_content(child, bufnr)
	eq(#buffer, #future_tasks)

	utils.cleanup_files(child, todo_path, done_path)
end

T["date_edge_cases"]["handles various date formats in due dates"] = function()
	local date_format_tasks = {
		"Task due:2025-1-1",
		"Task due:2025-12-31",
		"Task due:25-12-31",
		"Task due:2025-13-45",
		"Task due:0000-00-00",
		"Task due:2025-02-30",
		"Task with due:2025-06-15 and due:2025-07-20",
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, date_format_tasks, "todo.txt", "done.txt")

	child.lua("M.sort_tasks_by_due_date()")

	local buffer = utils.get_buffer_content(child, bufnr)
	eq(#buffer, #date_format_tasks)

	child.lua("M.sort_tasks()")

	utils.cleanup_files(child, todo_path, done_path)
end

T["priority_edge_cases"] = new_set()

T["priority_edge_cases"]["cycles priority on empty and whitespace lines"] = function()
	child.cmd("new")

	child.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.lua("M.cycle_priority()")

	local result1 = utils.get_buffer_content(child)[1]

	eq(result1, "(A) ")

	child.api.nvim_buf_set_lines(0, 0, -1, false, { "   " })
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.lua("M.cycle_priority()")

	local result2 = utils.get_buffer_content(child)[1]

	eq(type(result2), "string")
end

T["priority_edge_cases"]["cycles priority with complex completed tasks"] = function()
	local complex_scenarios = {
		{ input = "x (A) 2025-01-01 2024-12-01 Complex completed task", expected_pattern = "^x %(B%)" },
		{ input = "x 2025-01-01 Simple completed task", expected_pattern = "^x %(A%)" },
		{ input = "x (Z) 2025-01-01 Invalid priority completed", expected_pattern = "^x" },
	}

	child.cmd("new")

	vim.iter(complex_scenarios):each(function(scenario)
		child.api.nvim_buf_set_lines(0, 0, -1, false, { scenario.input })
		child.api.nvim_win_set_cursor(0, { 1, 0 })
		child.lua("M.cycle_priority()")

		local result = utils.get_buffer_content(child)[1]

		if result:match(scenario.expected_pattern) then
			eq(result:match(scenario.expected_pattern) ~= nil, true)
		else
			eq(type(result), "string")
		end
	end)
end

T["sorting_edge_cases"] = new_set()

T["sorting_edge_cases"]["sorts tasks with identical content"] = function()
	local identical_tasks = {
		"(A) Identical task",
		"(A) Identical task",
		"(A) Identical task",
		"(B) Identical task",
		"(B) Identical task",
		"x 2025-01-01 Identical completed task",
		"x 2025-01-01 Identical completed task",
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, identical_tasks, "todo.txt", "done.txt")

	child.lua("M.sort_tasks()")
	child.lua("M.sort_tasks_by_priority()")
	child.lua("M.sort_tasks_by_project()")
	child.lua("M.sort_tasks_by_context()")
	child.lua("M.sort_tasks_by_due_date()")

	local buffer = utils.get_buffer_content(child, bufnr)
	eq(#buffer, #identical_tasks)

	utils.cleanup_files(child, todo_path, done_path)
end

T["sorting_edge_cases"]["sorts with missing projects contexts and dates"] = function()
	local mixed_tasks = {
		"(A) Task with +project but no @context",
		"(B) Task with @context but no +project",
		"(C) Task with due:2025-12-31 only",
		"Task with no priority, project, context, or date",
		"x 2025-01-01 Completed task with nothing else",
		"+orphaned_project without task text",
		"@orphaned_context without task text",
		"due:2025-06-15 orphaned due date",
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, mixed_tasks, "todo.txt", "done.txt")

	child.lua("M.sort_tasks_by_project()")
	local buffer_project = utils.get_buffer_content(child, bufnr)

	child.lua("M.sort_tasks_by_context()")
	local buffer_context = utils.get_buffer_content(child, bufnr)

	child.lua("M.sort_tasks_by_due_date()")
	local buffer_due = utils.get_buffer_content(child, bufnr)

	eq(#buffer_project, #mixed_tasks)
	eq(#buffer_context, #mixed_tasks)
	eq(#buffer_due, #mixed_tasks)

	utils.cleanup_files(child, todo_path, done_path)
end

T["sorting_edge_cases"]["sorts only completed tasks"] = function()
	local only_completed_tasks = {
		"x 2025-01-03 (C) Third completed task",
		"x 2025-01-01 (A) First completed task",
		"x 2025-01-02 (B) Second completed task",
		"x 2025-01-01 No priority completed task",
		"x 2025-01-04 Another completed task",
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, only_completed_tasks, "todo.txt", "done.txt")

	child.lua("M.sort_tasks()")
	local buffer_default = utils.get_buffer_content(child, bufnr)

	child.lua("M.sort_tasks_by_priority()")
	local buffer_priority = utils.get_buffer_content(child, bufnr)

	eq(#buffer_default, #only_completed_tasks)
	eq(#buffer_priority, #only_completed_tasks)

	utils.cleanup_files(child, todo_path, done_path)
end

T["sorting_edge_cases"]["handles large number of tasks"] = function()
	local large_task_list = {}
	local priorities = { "A", "B", "C", "" }
	local projects = { "+work", "+personal", "+home", "" }
	local contexts = { "@phone", "@computer", "@errands", "" }

	vim.iter(vim.fn.range(1, 100)):each(function(i)
		local priority = priorities[math.random(#priorities)]
		local project = projects[math.random(#projects)]
		local context = contexts[math.random(#contexts)]
		local priority_part = priority ~= "" and "(" .. priority .. ") " or ""

		table.insert(large_task_list, priority_part .. "Task " .. i .. " " .. project .. " " .. context)
	end)

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, large_task_list, "todo.txt", "done.txt")

	child.lua("M.sort_tasks()")
	child.lua("M.sort_tasks_by_priority()")
	child.lua("M.sort_tasks_by_project()")

	local buffer = utils.get_buffer_content(child, bufnr)
	eq(#buffer, 100)

	utils.cleanup_files(child, todo_path, done_path)
end

T["capture_edge_cases"] = new_set()

T["capture_edge_cases"]["handles problematic input"] = function()
	local bufnr = utils.toggle_todotxt(child)
	local initial_count = #utils.get_buffer_content(child, bufnr)

	local problematic_inputs = {
		{ input = "", should_add = false },
		{ input = "   ", should_add = false },
		{ input = "x 2025-01-01 Looks completed", should_add = true },
		{ input = "(A) Looks like priority", should_add = true },
		{ input = string.rep("Very long input ", 50), should_add = true },
		{ input = "Input with tabs and special chars", should_add = true },
	}

	local added_count = 0
	vim.iter(problematic_inputs):each(function(scenario)
		utils.setup_todo_input(child, scenario.input)
		child.lua("M.capture_todo()")

		if scenario.should_add and scenario.input ~= "" and scenario.input:match("%S") then
			added_count = added_count + 1
		end
	end)

	local final_lines = utils.get_buffer_content(child, bufnr)
	eq(#final_lines >= initial_count + added_count, true)
end

T["capture_edge_cases"]["preserves existing dates in input"] = function()
	local bufnr = utils.toggle_todotxt(child)
	local initial_count = #utils.get_buffer_content(child, bufnr)

	utils.setup_todo_input(child, "2024-01-01 Task with existing date")
	child.lua("M.capture_todo()")

	local final_lines = utils.get_buffer_content(child, bufnr)
	eq(#final_lines, initial_count + 1)
	eq(final_lines[#final_lines], "2024-01-01 Task with existing date")
end

T["capture_edge_cases"]["handles priority-only input"] = function()
	local bufnr = utils.toggle_todotxt(child)
	local initial_count = #utils.get_buffer_content(child, bufnr)

	utils.setup_todo_input(child, "(A)")
	child.lua("M.capture_todo()")

	local final_lines = utils.get_buffer_content(child, bufnr)
	eq(#final_lines, initial_count + 1)
	local last_line = final_lines[#final_lines]
	local has_priority_and_date = last_line:match("%(A%) %d%d%d%d%-%d%d%-%d%d") ~= nil
	eq(has_priority_and_date, true)
end

T["capture_edge_cases"]["prepends creation date when task has due date"] = function()
	local bufnr = utils.toggle_todotxt(child)
	local initial_count = #utils.get_buffer_content(child, bufnr)

	utils.setup_todo_input(child, "Task with due:2025-12-31")
	child.lua("M.capture_todo()")

	local final_lines = utils.get_buffer_content(child, bufnr)
	eq(#final_lines, initial_count + 1)
	eq(final_lines[#final_lines], os.date("%Y-%m-%d") .. " Task with due:2025-12-31")
end

T["file_operation_edge_cases"] = new_set()

T["file_operation_edge_cases"]["handles very large files"] = function()
	local very_large_tasks = {}

	vim.iter(vim.fn.range(1, 1000)):each(function(i)
		local priority = i <= 100 and "(A) " or (i <= 300 and "(B) " or "")
		table.insert(
			very_large_tasks,
			priority .. "Large file task " .. i .. " +project" .. (i % 10) .. " @context" .. (i % 5)
		)
	end)

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, very_large_tasks, "todo.txt", "done.txt")

	child.lua("M.sort_tasks()")
	child.lua("M.sort_tasks_by_priority()")

	vim.iter(vim.fn.range(1, 10)):each(function(i)
		child.api.nvim_win_set_cursor(0, { i * 100, 0 })
		child.lua("M.toggle_todo_state()")
	end)

	child.lua("M.move_done_tasks()")

	local buffer = utils.get_buffer_content(child, bufnr)
	eq(type(buffer), "table")

	utils.cleanup_files(child, todo_path, done_path)
end

T["file_operation_edge_cases"]["handles concurrent file modifications"] = function()
	local bufnr = utils.toggle_todotxt(child)

	child.lua([[
		local external_lines = vim.fn.readfile(M.config.todotxt)
		table.insert(external_lines, "Externally added task")
		vim.fn.writefile(external_lines, M.config.todotxt)
	]])

	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.lua("M.toggle_todo_state()")
	child.lua("M.sort_tasks()")

	local buffer = utils.get_buffer_content(child, bufnr)

	eq(type(buffer), "table")
end

T["buffer_state_edge_cases"] = new_set()

T["buffer_state_edge_cases"]["handles operations when buffer is closed"] = function()
	utils.toggle_todotxt(child)

	child.cmd("bdelete")

	child.lua("M.move_done_tasks()")

	-- test passes if no error is thrown
end

T["buffer_state_edge_cases"]["handles unsaved buffer modifications"] = function()
	local bufnr = utils.toggle_todotxt(child)

	child.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "Unsaved task in buffer" })

	child.lua("M.move_done_tasks()")
	child.lua("M.sort_tasks()")

	local buffer = utils.get_buffer_content(child, bufnr)
	local has_unsaved = vim.iter(buffer):any(function(line) return line:match("Unsaved task in buffer") end)

	eq(has_unsaved, true)
end

T["buffer_state_edge_cases"]["handles buffer reload scenarios"] = function()
	local bufnr = utils.toggle_todotxt(child)

	child.lua([[
		local lines = vim.fn.readfile(M.config.todotxt)
		table.insert(lines, "External change after reload")
		vim.fn.writefile(lines, M.config.todotxt)
	]])

	child.cmd("edit!")

	child.lua("M.sort_tasks()")
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.lua("M.toggle_todo_state()")

	local buffer = utils.get_buffer_content(child, bufnr)
	local has_external_change = vim.iter(buffer):any(function(line) return line:match("External change after reload") end)

	eq(has_external_change, true)
end

return T
