local test = require("mini.test")
local eq = test.expect.equality

local M = {}

M.DEFAULT_TEST_TASKS = {
	"(A) Test task 1",
	"(B) Test task 2",
	"Simple task without priority",
}

M.PWD_TEST_TASKS = {
	"(A) PWD task 1",
	"(B) PWD task 2",
	"x 2025-01-01 PWD completed task",
}

M.RELATIVE_TEST_TASKS = {
	"(A) Relative task 1",
	"(B) Relative task 2",
	"Simple relative task",
}

---@param child MiniTest.child
---@param initial_task string
---@param expected_result string
M.test_priority_cycle = function(child, initial_task, expected_result)
	child.cmd("new")
	child.api.nvim_buf_set_lines(0, 0, -1, false, { initial_task })
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.lua("M.cycle_priority()")
	local result = M.get_buffer_content(child)[1]
	eq(result, expected_result)
end

---@param child MiniTest.child
---@param sort_func string
---@param shuffled_tasks string[]
---@param expected_tasks string[]
M.test_sort_function = function(child, sort_func, shuffled_tasks, expected_tasks)
	child.cmd("new")
	child.api.nvim_buf_set_lines(0, 0, -1, false, shuffled_tasks)
	child.lua("M." .. sort_func .. "()")
	local lines = M.get_buffer_content(child)
	eq(lines, expected_tasks)
end

---@param child MiniTest.child
---@param text string
M.setup_todo_input = function(child, text)
	child.lua([[vim.ui.input = function(opts, callback) callback("]] .. text .. [[") end]])
end

---@param child MiniTest.child
---@param todo_suffix string?
---@param done_suffix string?
---@return string todo_path
---@return string done_path
---@return nil temp_dir
M.create_temp_file_paths = function(child, todo_suffix, done_suffix)
	local temp_id = child.lua_get("string.format('%d_%d', vim.loop.now(), math.random(1000, 9999))")
	local cwd = child.lua_get("vim.fn.getcwd()")

	local todo_path = cwd .. "/test_" .. temp_id .. "_" .. (todo_suffix or "todo.txt")
	local done_path = cwd .. "/test_" .. temp_id .. "_" .. (done_suffix or "done.txt")

	return todo_path, done_path, nil
end

---@param child MiniTest.child
---@param todo_name string?
---@param done_name string?
---@return string todo_path
---@return string done_path
M.create_local_file_paths = function(child, todo_name, done_name)
	local todo_path = child.lua_get(string.format("vim.env.PWD .. '/%s'", todo_name or "todo.txt"))
	local done_path = child.lua_get(string.format("vim.env.PWD .. '/%s'", done_name or "done.txt"))
	return todo_path, done_path
end

---@param child MiniTest.child
---@param file_path string
---@param tasks string[]?
M.create_test_todo_file = function(child, file_path, tasks)
	local task_list = tasks or M.DEFAULT_TEST_TASKS

	child.lua(
		string.format(
			"vim.fn.writefile({ %s }, %q)",
			table.concat(vim.tbl_map(function(task) return string.format("%q", task) end, task_list), ",\n\t\t\t"),
			file_path
		)
	)
end

---@param child MiniTest.child
---@param tasks string[]?
---@param todo_suffix string?
---@param done_suffix string?
---@return integer bufnr
---@return string todo_path
---@return string done_path
---@return nil temp_dir
M.setup_temp_files = function(child, tasks, todo_suffix, done_suffix)
	local todo_path, done_path, temp_dir = M.create_temp_file_paths(child, todo_suffix, done_suffix)
	M.create_test_todo_file(child, todo_path, tasks)
	child.lua(string.format("M.setup({ todotxt = %q, donetxt = %q })", todo_path, done_path))
	local bufnr = child.lua("M.toggle_todotxt(); return vim.api.nvim_get_current_buf()")
	return bufnr, todo_path, done_path, temp_dir
end

---@param child MiniTest.child
---@param todo_path string
---@param done_path string
---@param tasks string[]?
---@return integer bufnr
M.setup_local_files = function(child, todo_path, done_path, tasks)
	M.create_test_todo_file(child, todo_path, tasks)
	child.lua(string.format("M.setup({ todotxt = %q, donetxt = %q })", todo_path, done_path))
	return child.lua("M.toggle_todotxt(); return vim.api.nvim_get_current_buf()")
end

---@param child MiniTest.child
---@param ... string
M.cleanup_files = function(child, ...)
	vim.iter({ ... }):each(function(path)
		if path then
			if child.lua_get(string.format("vim.fn.isdirectory(%q)", path)) == 1 then
				child.lua(string.format("vim.fn.delete(%q, 'rf')", path))
			elseif child.lua_get(string.format("vim.fn.filereadable(%q)", path)) == 1 then
				child.lua(string.format("vim.fn.delete(%q)", path))
			end
		end
	end)
end

---@param child MiniTest.child
---@param temp_dir string?
M.cleanup_temp_dir = function(child, temp_dir)
	if temp_dir and child.lua_get(string.format("vim.fn.isdirectory(%q)", temp_dir)) == 1 then
		child.lua(string.format("vim.fn.delete(%q, 'rf')", temp_dir))
	end
end

---@param child MiniTest.child
---@param file_path string
M.assert_file_not_exists = function(child, file_path)
	eq(child.lua_get(string.format("vim.fn.filereadable(%q)", file_path)), 0)
end

---@param child MiniTest.child
---@param file_path string
M.assert_file_exists = function(child, file_path)
	eq(child.lua_get(string.format("vim.fn.filereadable(%q)", file_path)), 1)
end

---@param lines string[]
---@param line_num integer
---@param expected_date string
---@param task_text string
---@param has_priority boolean
M.assert_task_completed = function(lines, line_num, expected_date, task_text, has_priority)
	local pattern = has_priority and "^x %(%w%) %d%d%d%d%-%d%d%-%d%d" or "^x %d%d%d%d%-%d%d%-%d%d"
	local expected = has_priority and ("x (B) " .. expected_date) or ("x " .. expected_date)
	eq(lines[line_num]:match(pattern), expected)
	eq(lines[line_num]:match(task_text), task_text)
end

---@param child MiniTest.child
---@param bufnr integer?
---@return string[]
M.get_buffer_content = function(child, bufnr) return child.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false) end

---@param child MiniTest.child
---@return integer bufnr
---@return integer win
M.toggle_todotxt = function(child)
	child.lua("M.toggle_todotxt()")
	return child.api.nvim_get_current_buf(), child.api.nvim_get_current_win()
end

---@param child MiniTest.child
---@param win integer
---@param line_num integer
M.toggle_line_todo_state = function(child, win, line_num)
	child.api.nvim_win_set_cursor(win, { line_num, 0 })
	child.lua("M.toggle_todo_state()")
end

---@param lines string[]?
---@return integer
M.count_completed_tasks = function(lines)
	return vim
		.iter(lines or {})
		:filter(function(line) return line:match("^x ") end)
		:fold(0, function(count) return count + 1 end)
end

return M
