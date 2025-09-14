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

T["ghost_text.setup()"] = new_set()

T["ghost_text.setup()"]["initializes with default config when disabled"] = function()
	child.lua("require('todotxt.ghost_text').setup({ enable = false })")

	local ns_exists = child.lua_get("vim.api.nvim_get_namespaces()['todotxt_ghost_text'] ~= nil")
	eq(ns_exists, false)
end

T["ghost_text.setup()"]["initializes with custom config when enabled"] = function()
	child.lua([[require('todotxt.ghost_text').setup({
		enable = true,
		mappings = { ["(A)"] = "urgent", ["(B)"] = "important" },
		prefix = ">>> ",
		highlight = "ErrorMsg"
	})]])

	local ns_exists = child.lua_get("vim.api.nvim_get_namespaces()['todotxt_ghost_text'] ~= nil")
	eq(ns_exists, true)
end

T["ghost_text.update()"] = new_set()

T["ghost_text.update()"]["displays ghost text for priority patterns"] = function()
	local tasks = {
		"(A) High priority task",
		"(B) Medium priority task",
		"(C) Low priority task",
		"Regular task without priority",
		"x (A) Completed high priority task",
	}

	local _, todo_path, done_path, _ = utils.setup_temp_files(child, tasks, "todo.txt", "done.txt")

	child.lua("require('todotxt.ghost_text').setup({ enable = true })")
	child.lua("require('todotxt.ghost_text').update()")

	child.lua("ns_id = vim.api.nvim_get_namespaces()['todotxt_ghost_text']")
	local extmarks = child.lua_get("vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, { details = true })")

	eq(#extmarks, 3)

	local expected_texts = { "now", "next", "today" }
	for i, extmark in ipairs(extmarks) do
		local virt_text = extmark[4].virt_text[1][1]
		eq(virt_text, " " .. expected_texts[i])
	end

	utils.cleanup_files(child, todo_path, done_path)
end

T["ghost_text.update()"]["handles tasks with indentation"] = function()
	local tasks = {
		"  (A) Indented high priority task",
		"\t(B) Tab indented task",
		"    (C) Multiple space indented task",
	}

	local _, todo_path, done_path, _ = utils.setup_temp_files(child, tasks, "todo.txt", "done.txt")

	child.lua("require('todotxt.ghost_text').setup({ enable = true })")
	child.lua("require('todotxt.ghost_text').update()")

	child.lua("ns_id = vim.api.nvim_get_namespaces()['todotxt_ghost_text']")
	local extmarks = child.lua_get("vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, { details = true })")

	eq(#extmarks, 3)

	utils.cleanup_files(child, todo_path, done_path)
end

T["ghost_text.update()"]["ignores malformed priority patterns"] = function()
	local tasks = {
		"(AA) Invalid double letter",
		"(1) Numeric priority",
		"(a) Lowercase priority",
		"() Empty priority",
		"( ) Space priority",
		"(A) Valid priority",
	}

	local _, todo_path, done_path, _ = utils.setup_temp_files(child, tasks, "todo.txt", "done.txt")

	child.lua("require('todotxt.ghost_text').setup({ enable = true })")
	child.lua("require('todotxt.ghost_text').update()")

	child.lua("ns_id = vim.api.nvim_get_namespaces()['todotxt_ghost_text']")
	local extmarks = child.lua_get("vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, { details = true })")

	eq(#extmarks, 1)

	utils.cleanup_files(child, todo_path, done_path)
end

T["ghost_text.enable()"] = new_set()

T["ghost_text.enable()"]["enables ghost text and creates namespace"] = function()
	child.lua("require('todotxt.ghost_text').setup({ enable = false })")
	child.lua("require('todotxt.ghost_text').enable()")

	local ns_exists = child.lua_get("vim.api.nvim_get_namespaces()['todotxt_ghost_text'] ~= nil")
	eq(ns_exists, true)
end

T["ghost_text.disable()"] = new_set()

T["ghost_text.disable()"]["clears all extmarks"] = function()
	local tasks = { "(A) Test task", "(B) Another task" }
	local _, todo_path, done_path, _ = utils.setup_temp_files(child, tasks, "todo.txt", "done.txt")

	child.lua("require('todotxt.ghost_text').setup({ enable = true })")
	child.lua("require('todotxt.ghost_text').update()")

	child.lua("ns_id = vim.api.nvim_get_namespaces()['todotxt_ghost_text']")
	local extmarks_before = child.lua_get("#vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})")
	eq(extmarks_before, 2)

	child.lua("require('todotxt.ghost_text').disable()")

	local extmarks_after = child.lua_get("#vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})")
	eq(extmarks_after, 0)

	utils.cleanup_files(child, todo_path, done_path)
end

T["ghost_text.toggle()"] = new_set()

T["ghost_text.toggle()"]["toggles between enabled and disabled states"] = function()
	local tasks = { "(A) Test task" }
	local _, todo_path, done_path, _ = utils.setup_temp_files(child, tasks, "todo.txt", "done.txt")

	child.lua("require('todotxt.ghost_text').setup({ enable = true })")

	child.lua("require('todotxt.ghost_text').toggle()")

	child.lua("ns_id = vim.api.nvim_get_namespaces()['todotxt_ghost_text']")
	local extmarks_disabled = child.lua_get("#vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})")
	eq(extmarks_disabled, 0)

	child.lua("require('todotxt.ghost_text').toggle()")

	local extmarks_re_enabled = child.lua_get("#vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})")
	eq(extmarks_re_enabled, 1)

	utils.cleanup_files(child, todo_path, done_path)
end

T["ghost_text.edge_cases"] = new_set()

T["ghost_text.edge_cases"]["handles empty buffer"] = function()
	child.cmd("new")
	child.lua("require('todotxt.ghost_text').setup({ enable = true })")
	child.lua("require('todotxt.ghost_text').update()")

	child.lua("ns_id = vim.api.nvim_get_namespaces()['todotxt_ghost_text']")
	local extmarks = child.lua_get("#vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})")

	eq(extmarks, 0)
end

T["ghost_text.edge_cases"]["handles priority patterns mid-line"] = function()
	local tasks = {
		"Some text (A) priority in middle",
		"End with (B)",
		"(C) Start correctly",
	}

	local _, todo_path, done_path, _ = utils.setup_temp_files(child, tasks, "todo.txt", "done.txt")

	child.lua("require('todotxt.ghost_text').setup({ enable = true })")
	child.lua("require('todotxt.ghost_text').update()")

	child.lua("ns_id = vim.api.nvim_get_namespaces()['todotxt_ghost_text']")
	local extmarks = child.lua_get("#vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})")

	eq(extmarks, 1)

	utils.cleanup_files(child, todo_path, done_path)
end

T["ghost_text.edge_cases"]["handles disabled state gracefully"] = function()
	local tasks = { "(A) Test task" }
	local _, todo_path, done_path, _ = utils.setup_temp_files(child, tasks, "todo.txt", "done.txt")

	child.lua("require('todotxt.ghost_text').setup({ enable = false })")
	child.lua("require('todotxt.ghost_text').update()")

	local ns_exists = child.lua_get("vim.api.nvim_get_namespaces()['todotxt_ghost_text'] ~= nil")
	eq(ns_exists, false)

	utils.cleanup_files(child, todo_path, done_path)
end

return T

