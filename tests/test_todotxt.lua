local test = require("mini.test")
local new_set, eq = test.new_set, test.expect.equality

local child = test.new_child_neovim()

local T = new_set({
	hooks = {
		pre_case = function() child.restart({ "-u", "scripts/minimal_init.lua" }) end,
		post_once = function()
			vim.fs.rm("/tmp/todotxt.nvim", {
				recursive = true,
				force = true,
			})
			child.stop()
		end,
	},
})

local get_buffer_content = function(bufnr) return child.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false) end

local open_todo_file = function()
	child.lua("M.open_todo_file()")
	return child.api.nvim_get_current_buf()
end

local test_priority_cycle = function(initial_task, expected_result)
	child.cmd("new")
	child.api.nvim_buf_set_lines(0, 0, -1, false, { initial_task })
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.lua("M.cycle_priority()")
	local result = get_buffer_content()[1]
	eq(result, expected_result)
end

local test_sort_function = function(sort_func, shuffled_tasks, expected_tasks)
	child.cmd("new")
	child.api.nvim_buf_set_lines(0, 0, -1, false, shuffled_tasks)
	child.lua("M." .. sort_func .. "()")
	local lines = get_buffer_content()
	eq(lines, expected_tasks)
end

local setup_todo_input = function(text)
	child.lua([[vim.ui.input = function(opts, callback) callback("]] .. text .. [[") end]])
end

T["open_todo_file()"] = new_set()

T["open_todo_file()"]["check file content"] = function()
	local bufnr = open_todo_file()
	local lines = get_buffer_content(bufnr)

	eq(#lines, 4)
	eq(lines[1]:match("^%(A%) Test task 1"), "(A) Test task 1")
	eq(lines[2]:match("^%(B%) Test task 2"), "(B) Test task 2")
	eq(lines[3]:match("^%(C%) Test task 3"), "(C) Test task 3")
	eq(lines[4]:match("^x 2025%-01%-01 Test task 4"), "x 2025-01-01 Test task 4")
end

T["toggle_todo_state()"] = new_set()

T["toggle_todo_state()"]["marks completed task as incomplete"] = function()
	open_todo_file()

	child.api.nvim_win_set_cursor(0, { 4, 0 }) -- line 4 is completed

	child.lua("M.toggle_todo_state()")

	local lines = get_buffer_content()

	eq(lines[4]:match("^x"), nil)
end

T["toggle_todo_state()"]["marks incomplete task as completed"] = function()
	open_todo_file()

	child.api.nvim_win_set_cursor(0, { 1, 0 }) -- line 1 is incomplete

	child.lua("M.toggle_todo_state()")

	local lines = get_buffer_content()

	eq(lines[1]:match("^x %d%d%d%d%-%d%d%-%d%d"), "x " .. os.date("%Y-%m-%d"))
end

T["sort_tasks()"] = new_set()

T["sort_tasks()"]["doesn't crash with empty todo.txt"] = function()
	child.lua([[vim.fn.writefile({}, M.config.todotxt)]])

	child.lua("M.sort_tasks()")

	eq(get_buffer_content(open_todo_file()), { "" })
end

T["sort_tasks()"]["sorts tasks"] = function()
	local expected_tasks = {
		"2025-01-03 Test task 1",
		"2025-01-02 Test task 2",
		"2025-01-01 Test task 3",
		"x 2025-01-01 Test task 4",
	}

	local shuffled_tasks = {
		"2025-01-02 Test task 2",
		"2025-01-03 Test task 1",
		"x 2025-01-01 Test task 4",
		"2025-01-01 Test task 3",
	}

	test_sort_function("sort_tasks", shuffled_tasks, expected_tasks)
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

	test_sort_function("sort_tasks_by_priority", shuffled_tasks, expected_tasks)
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

	test_sort_function("sort_tasks_by_project", shuffled_tasks, expected_tasks)
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

	test_sort_function("sort_tasks_by_project", shuffled_tasks, expected_tasks)
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

	test_sort_function("sort_tasks_by_context", shuffled_tasks, expected_tasks)
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

	test_sort_function("sort_tasks_by_due_date", shuffled_tasks, expected_tasks)
end

T["cycle_priority()"] = new_set()

T["cycle_priority()"]["cycles priority A to B"] = function()
	test_priority_cycle("(A) Test priority cycling", "(B) Test priority cycling")
end

T["cycle_priority()"]["cycles priority B to C"] = function()
	test_priority_cycle("(B) Test priority cycling", "(C) Test priority cycling")
end

T["cycle_priority()"]["cycles priority C to no priority"] = function()
	test_priority_cycle("(C) Test priority cycling", "Test priority cycling")
end

T["cycle_priority()"]["cycles no priority to A"] = function()
	test_priority_cycle("Test priority cycling", "(A) Test priority cycling")
end

T["capture_todo()"] = new_set()

T["capture_todo()"]["adds new todo to current buffer when it is todo.txt"] = function()
	local bufnr = open_todo_file()
	local initial_lines = get_buffer_content(bufnr)

	setup_todo_input("New test todo")
	child.lua("M.capture_todo()")

	local new_lines = get_buffer_content(bufnr)
	eq(#new_lines, #initial_lines + 1)

	local today = os.date("%Y-%m-%d")
	eq(new_lines[#new_lines], today .. " New test todo")
end

T["capture_todo()"]["adds new todo to file when buffer is not todo.txt"] = function()
	local initial_lines = child.lua_get("vim.fn.readfile(M.config.todotxt)")

	setup_todo_input("New test todo")
	child.lua("M.capture_todo()")

	local new_lines = get_buffer_content(open_todo_file())

	eq(#new_lines, #initial_lines + 1)

	local today = os.date("%Y-%m-%d")
	eq(new_lines[#new_lines], today .. " New test todo")
end

T["move_done_tasks()"] = new_set()

T["move_done_tasks()"]["moves completed tasks to done.txt"] = function()
	local bufnr = open_todo_file()

	local todo_lines_before = get_buffer_content(bufnr)
	local done_lines_before = child.lua_get("vim.fn.readfile(M.config.donetxt)")

	eq(#done_lines_before, 0)

	child.lua("M.move_done_tasks()")

	local done_lines_after = child.lua_get("vim.fn.readfile(M.config.donetxt)")
	local todo_lines_after = get_buffer_content(bufnr)

	eq(#todo_lines_after, 3)
	eq(#done_lines_after, 1)
	eq(todo_lines_before[4], done_lines_after[1])
end

return T
