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

	eq(child.lua_get("vim.api.nvim_get_namespaces()['todotxt_ghost_text'] ~= nil"), false)
end

T["ghost_text.setup()"]["initializes with custom config when enabled"] = function()
	child.lua([[require('todotxt.ghost_text').setup({
		enable = true,
		mappings = { ["(A)"] = "urgent", ["(B)"] = "important" },
		prefix = ">>> ",
		highlight = "ErrorMsg"
	})]])

	eq(child.lua_get("vim.api.nvim_get_namespaces()['todotxt_ghost_text'] ~= nil"), true)
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

	utils.setup_ghost_text(child)

	local extmarks = utils.get_extmarks_detailed(child)

	eq(#extmarks, 3)

	local expected_texts = { "now", "next", "today" }

	vim.iter(ipairs(extmarks)):each(function(i, extmark)
		local virt_text = extmark[4].virt_text[1][1]
		eq(virt_text, " " .. expected_texts[i])
	end)

	utils.cleanup_files(child, todo_path, done_path)
end

T["ghost_text.update()"]["handles tasks with indentation"] = function()
	local tasks = {
		"  (A) Indented high priority task",
		"\t(B) Tab indented task",
		"    (C) Multiple space indented task",
	}

	local _, todo_path, done_path, _ = utils.setup_temp_files(child, tasks, "todo.txt", "done.txt")

	utils.setup_ghost_text(child)
	eq(utils.get_extmarks_count(child), 3)

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

	utils.setup_ghost_text(child)
	eq(utils.get_extmarks_count(child), 1)

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

	utils.setup_ghost_text(child)
	eq(utils.get_extmarks_count(child), 2)

	child.lua("require('todotxt.ghost_text').disable()")
	eq(utils.get_extmarks_count(child), 0)

	utils.cleanup_files(child, todo_path, done_path)
end

T["ghost_text.toggle()"] = new_set()

T["ghost_text.toggle()"]["toggles between enabled and disabled states"] = function()
	local tasks = { "(A) Test task" }
	local _, todo_path, done_path, _ = utils.setup_temp_files(child, tasks, "todo.txt", "done.txt")

	utils.setup_ghost_text(child)
	child.lua("require('todotxt.ghost_text').toggle()")
	eq(utils.get_extmarks_count(child), 0)

	child.lua("require('todotxt.ghost_text').toggle()")
	eq(utils.get_extmarks_count(child), 1)

	utils.cleanup_files(child, todo_path, done_path)
end

T["ghost_text.edge_cases"] = new_set()

T["ghost_text.edge_cases"]["handles empty buffer"] = function()
	child.cmd("new")
	utils.setup_ghost_text(child)
	eq(utils.get_extmarks_count(child), 0)
end

T["ghost_text.edge_cases"]["handles priority patterns mid-line"] = function()
	local tasks = {
		"Some text (A) priority in middle",
		"End with (B)",
		"(C) Start correctly",
	}

	local _, todo_path, done_path, _ = utils.setup_temp_files(child, tasks, "todo.txt", "done.txt")

	utils.setup_ghost_text(child)
	eq(utils.get_extmarks_count(child), 1)

	utils.cleanup_files(child, todo_path, done_path)
end

T["ghost_text.edge_cases"]["handles disabled state gracefully"] = function()
	local tasks = { "(A) Test task" }
	local _, todo_path, done_path, _ = utils.setup_temp_files(child, tasks, "todo.txt", "done.txt")

	utils.setup_ghost_text(child, { enable = false })
	child.lua("require('todotxt.ghost_text').update()")

	local ns_exists = child.lua_get("vim.api.nvim_get_namespaces()['todotxt_ghost_text'] ~= nil")
	eq(ns_exists, false)

	utils.cleanup_files(child, todo_path, done_path)
end

return T
