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
			for _, file in ipairs(test_files) do
				child.lua(string.format("vim.fn.delete(%q)", file))
			end
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
	local lines = utils.get_buffer_content(child, bufnr)

	local expected_lines = {
		"(A) Test task 1",
		"(B) Test task 2",
		"(C) Test task 3",
		"x 2025-01-01 Test task 4",
		"2025-01-01 Test task 5",
	}

	eq(#lines, 5)

	vim.iter(ipairs(expected_lines)):each(function(i, line) eq(lines[i]:match("^" .. vim.pesc(line)), line) end)
end

T["toggle_todo_state()"] = new_set()

T["toggle_todo_state()"]["marks completed task as incomplete"] = function()
	utils.toggle_todotxt(child)

	child.api.nvim_win_set_cursor(0, { 4, 0 }) -- line 4 is completed

	child.lua("M.toggle_todo_state()")

	local lines = utils.get_buffer_content(child)

	eq(lines[4]:match("^x"), nil)
	eq(lines[4]:match("Test task 4"), "Test task 4")
end

T["toggle_todo_state()"]["marks incomplete task as completed"] = function()
	utils.toggle_todotxt(child)

	child.api.nvim_win_set_cursor(0, { 5, 0 }) -- line 1 is incomplete

	child.lua("M.toggle_todo_state()")

	local lines = utils.get_buffer_content(child)

	eq(lines[5]:match("^x %d%d%d%d%-%d%d%-%d%d"), "x " .. os.date("%Y-%m-%d"))
	eq(lines[5]:match("Test task 5"), "Test task 5")
end

T["toggle_todo_state()"]["marks incompleted task with priority as completed"] = function()
	utils.toggle_todotxt(child)

	child.api.nvim_win_set_cursor(0, { 1, 0 }) -- line 1 is incompleted with priority

	child.lua("M.toggle_todo_state()")

	local lines = utils.get_buffer_content(child)

	eq(lines[1]:match("^x %(%a%) %d%d%d%d%-%d%d%-%d%d"), "x (A) " .. os.date("%Y-%m-%d"))
	eq(lines[1]:match("Test task 1"), "Test task 1")
end

T["toggle_todo_state()"]["marks completed task with priority as incompleted"] = function()
	utils.toggle_todotxt(child)

	child.api.nvim_win_set_cursor(0, { 1, 0 }) -- line 1 is incompleted with priority

	child.lua("M.toggle_todo_state()")
	child.lua("M.toggle_todo_state()")

	local lines = utils.get_buffer_content(child)

	eq(lines[1]:match("^%(%a%)"), "(A)")
	eq(lines[1]:match("Test task 1"), "Test task 1")
end

T["toggle_todo_state()"]["handles task with unusual formatting"] = function()
	utils.toggle_todotxt(child)

	child.api.nvim_buf_set_lines(0, 0, -1, false, { "(A)   Multiple spaces   +project   @context" })
	child.api.nvim_win_set_cursor(0, { 1, 0 })

	child.lua("M.toggle_todo_state()")

	local lines = utils.get_buffer_content(child)
	eq(lines[1]:match("^x %(%a%) %d%d%d%d%-%d%d%-%d%d"), "x (A) " .. os.date("%Y-%m-%d"))
	eq(lines[1]:match("Multiple spaces   %+project   @context$"), "Multiple spaces   +project   @context")
end

T["toggle_todo_state()"]["toggles completed tasks without dates"] = function()
	utils.toggle_todotxt(child)

	child.api.nvim_buf_set_lines(0, 0, -1, false, { "x Simple task without date" })
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.lua("M.toggle_todo_state()")

	local lines = utils.get_buffer_content(child)
	eq(lines[1], "Simple task without date")

	child.lua("M.toggle_todo_state()")
	lines = utils.get_buffer_content(child)
	eq(lines[1], "x " .. os.date("%Y-%m-%d") .. " Simple task without date")

	child.api.nvim_buf_set_lines(0, 0, -1, false, { "x (A) Simple task without date" })
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.lua("M.toggle_todo_state()")

	lines = utils.get_buffer_content(child)
	eq(lines[1], "(A) Simple task without date")

	child.lua("M.toggle_todo_state()")
	lines = utils.get_buffer_content(child)
	eq(lines[1], "x (A) " .. os.date("%Y-%m-%d") .. " Simple task without date")
end

T["toggle_todo_state()"]["does not create done.txt when toggling task state"] = function()
	utils.toggle_todotxt(child)

	local done_lines_before
	local done_file_exists_before = child.lua_get("vim.fn.filereadable(M.config.donetxt)")

	if done_file_exists_before == 1 then
		done_lines_before = child.lua_get("vim.fn.readfile(M.config.donetxt)")
	else
		done_lines_before = {}
	end

	child.api.nvim_win_set_cursor(0, { 5, 0 }) -- line 5 is incomplete
	child.lua("M.toggle_todo_state()")

	local done_file_exists_after = child.lua_get("vim.fn.filereadable(M.config.donetxt)")
	local done_lines_after = {}
	if done_file_exists_after == 1 then done_lines_after = child.lua_get("vim.fn.readfile(M.config.donetxt)") end

	eq(done_file_exists_before, done_file_exists_after)
	eq(done_lines_before, done_lines_after)

	local lines = utils.get_buffer_content(child)

	eq(lines[5]:match("^x %d%d%d%d%-%d%d%-%d%d"), "x " .. os.date("%Y-%m-%d"))
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

T["toggle_todo_state()"]["does not modify done.txt when toggling with local and relative file paths"] = function()
	local custom_tasks = {
		"(A) Local task 1",
		"(B) Local task 2",
		"Simple task without priority",
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, custom_tasks, "todo.txt", "done.txt")

	utils.assert_file_exists(child, done_path)

	local done_lines_before = child.lua_get(string.format("vim.fn.readfile(%q)", done_path))

	eq(#done_lines_before, 0)

	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.lua("M.toggle_todo_state()")

	local done_lines_after = child.lua_get(string.format("vim.fn.readfile(%q)", done_path))
	eq(#done_lines_after, 0)

	local lines = utils.get_buffer_content(child, bufnr)
	utils.assert_task_completed(lines, 2, os.date("%Y-%m-%d"), "Local task 2", true)

	utils.cleanup_files(child, todo_path, done_path)

	local rel_bufnr, rel_todo_path, rel_done_path, _ =
		utils.setup_temp_files(child, utils.RELATIVE_TEST_TASKS, "todo.txt", "one.txt")

	utils.assert_file_exists(child, rel_done_path)
	done_lines_before = child.lua_get(string.format("vim.fn.readfile(%q)", rel_done_path))
	eq(#done_lines_before, 0)

	child.api.nvim_win_set_cursor(0, { 1, 0 })

	child.lua("M.toggle_todo_state()")

	done_lines_after = child.lua_get(string.format("vim.fn.readfile(%q)", rel_done_path))
	eq(#done_lines_after, 0)

	lines = utils.get_buffer_content(child, rel_bufnr)
	eq(lines[1]:match("^x"), "x")

	utils.cleanup_files(child, rel_todo_path, rel_done_path)
end

T["toggle_todo_state()"]["populates done.txt when using local files and moving tasks"] = function()
	local local_tasks = {
		"(A) Local task 1",
		"(B) Local task 2",
		"x 2025-01-01 Local completed task",
	}

	local bufnr, todo_path, done_path, _ = utils.setup_temp_files(child, local_tasks, "todo.txt", "done.txt")

	utils.assert_file_exists(child, done_path)

	local done_lines_before = child.lua_get(string.format("vim.fn.readfile(%q)", done_path))

	eq(#done_lines_before, 0)

	child.lua("M.move_done_tasks()")

	local done_lines_after = child.lua_get(string.format("vim.fn.readfile(%q)", done_path))
	eq(#done_lines_after, 1)
	eq(done_lines_after[1], "x 2025-01-01 Local completed task")

	local todo_lines = utils.get_buffer_content(child, bufnr)
	eq(#todo_lines, 2)

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

T["sort_tasks_by_priority()"]["sorts tasks by priority"] = function()
	local expected_tasks = {
		"(A) Test task 1",
		"(B) Test task 2",
		"(C) Test task 3",
		"x 2025-01-01 Test task 4",
	}

	local shuffled_tasks = {
		"(B) Test task 2",
		"x 2025-01-01 Test task 4",
		"(C) Test task 3",
		"(A) Test task 1",
	}

	utils.test_sort_function(child, "sort_tasks_by_priority", shuffled_tasks, expected_tasks)
end

T["sort_tasks_by_project()"] = new_set()

T["sort_tasks_by_project()"]["sorts tasks by project"] = function()
	local expected_tasks = {
		"(C) Test task 3 +project1",
		"(B) Test task 2 +project2",
		"(A) Test task 1 +project3",
		"x 2025-01-01 Test task 4 +project4",
	}

	local shuffled_tasks = {
		"(A) Test task 1 +project3",
		"(B) Test task 2 +project2",
		"(C) Test task 3 +project1",
		"x 2025-01-01 Test task 4 +project4",
	}

	utils.test_sort_function(child, "sort_tasks_by_project", shuffled_tasks, expected_tasks)
end

T["sort_tasks_by_project()"]["handles multiple projects per task"] = function()
	local expected_tasks = {
		"(A) Task with +multiple +projects",
		"(B) Task with +one_project",
	}

	local shuffled_tasks = {
		"(B) Task with +one_project",
		"(A) Task with +multiple +projects",
	}

	utils.test_sort_function(child, "sort_tasks_by_project", shuffled_tasks, expected_tasks)
end

T["sort_tasks_by_context()"] = new_set()

T["sort_tasks_by_context()"]["sorts tasks by context"] = function()
	local expected_tasks = {
		"(A) Test task 1 @context1",
		"(B) Test task 2 @context2",
		"(C) Test task 3 @context3",
		"x 2025-01-01 Test task 4 @context1",
	}

	local shuffled_tasks = {
		"(B) Test task 2 @context2",
		"(A) Test task 1 @context1",
		"x 2025-01-01 Test task 4 @context1",
		"(C) Test task 3 @context3",
	}

	utils.test_sort_function(child, "sort_tasks_by_context", shuffled_tasks, expected_tasks)
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

T["cycle_priority()"]["cycles priority A to B"] = function()
	utils.test_priority_cycle(child, "(A) Test priority cycling", "(B) Test priority cycling")
end

T["cycle_priority()"]["cycles priority B to C"] = function()
	utils.test_priority_cycle(child, "(B) Test priority cycling", "(C) Test priority cycling")
end

T["cycle_priority()"]["cycles priority C to no priority"] = function()
	utils.test_priority_cycle(child, "(C) Test priority cycling", "Test priority cycling")
end

T["cycle_priority()"]["cycles no priority to A"] = function()
	utils.test_priority_cycle(child, "Test priority cycling", "(A) Test priority cycling")
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

	for _, scenario in ipairs(scenarios) do
		child.cmd("new")
		child.api.nvim_buf_set_lines(0, 0, -1, false, { scenario.initial })
		child.api.nvim_win_set_cursor(0, { 1, 0 })
		child.lua("M.cycle_priority()")
		local result = child.api.nvim_buf_get_lines(0, 0, -1, false)[1]
		eq(result, scenario.expected)
	end
end

T["capture_todo()"] = new_set()

T["capture_todo()"]["adds new todo to current buffer when it is todo.txt"] = function()
	local bufnr = utils.toggle_todotxt(child)
	local initial_lines = utils.get_buffer_content(child, bufnr)

	utils.setup_todo_input(child, "New test todo")
	child.lua("M.capture_todo()")

	local new_lines = utils.get_buffer_content(child, bufnr)

	eq(#new_lines, #initial_lines + 1)
	eq(new_lines[#new_lines], os.date("%Y-%m-%d") .. " New test todo")
end

T["capture_todo()"]["adds new todo to file when buffer is not todo.txt"] = function()
	local initial_lines = child.lua_get("vim.fn.readfile(M.config.todotxt)")

	utils.setup_todo_input(child, "New test todo")
	child.lua("M.capture_todo()")

	local new_lines = utils.get_buffer_content(child, utils.toggle_todotxt(child))

	eq(#new_lines, #initial_lines + 1)
	eq(new_lines[#new_lines], os.date("%Y-%m-%d") .. " New test todo")
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

	for _, scenario in ipairs(scenarios) do
		child.lua([[vim.ui.input = function(opts, callback) callback("]] .. scenario.input .. [[") end]])
		child.lua("M.capture_todo()")

		local new_lines = utils.get_buffer_content(child, bufnr)

		if scenario.should_add then
			added_count = added_count + 1
			eq(#new_lines, line_count + added_count)
			eq(new_lines[#new_lines], scenario.expected)
		else
			eq(#new_lines, line_count + added_count)
		end
	end
end

T["move_done_tasks()"] = new_set()

T["move_done_tasks()"]["moves completed tasks to done.txt"] = function()
	local bufnr = utils.toggle_todotxt(child)

	local todo_lines_before = utils.get_buffer_content(child, bufnr)
	local done_lines_before = child.lua_get("vim.fn.readfile(M.config.donetxt)")

	eq(#done_lines_before, 0)

	child.lua("M.move_done_tasks()")

	local done_lines_after = child.lua_get("vim.fn.readfile(M.config.donetxt)")
	local todo_lines_after = utils.get_buffer_content(child, bufnr)

	eq(#todo_lines_after, 4)
	eq(#done_lines_after, 1)
	eq(todo_lines_before[4], done_lines_after[1])
end

return T
