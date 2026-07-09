local test = require("mini.test")
local utils = require("tests.utils")
local eq = test.expect.equality
local Kind = vim.lsp.protocol.CompletionItemKind

local child, T = utils.new_child_set()

T["completion"] = test.new_set()

T["completion"]["shows all priorities for current ring"] = function()
	utils.setup_lsp_test(child, { "(A) Task one", "Simple task" })
	utils.call_lsp_handler(child, "textDocument/completion", {
		textDocument = { uri = "" },
		position = { line = 0, character = 0 },
	})

	local items = child.lua_get("_G.lsp_result.items")
	local labels = vim.iter(items):map(function(i) return i.label end):totable()

	eq(true, vim.list_contains(labels, "(A)"))
	eq(true, vim.list_contains(labels, "(B)"))
	eq(true, vim.list_contains(labels, "(C)"))

	local priority_items = vim.iter(items):filter(function(i) return i.label:match("^%(%a%)$") end):totable()
	eq(true, #priority_items > 0)

	vim.iter(priority_items):each(function(i)
		eq(Kind.Keyword, i.kind)
		eq(" Priority", i.labelDetails.detail)
	end)
end

T["completion"]["shows all projects from buffer"] = function()
	utils.setup_lsp_test(child, { "+myproject Task one", "+otherproj Task two" })
	utils.call_lsp_handler(child, "textDocument/completion", {
		textDocument = { uri = "" },
		position = { line = 0, character = 0 },
	})

	local items = child.lua_get("_G.lsp_result.items")
	local labels = vim.iter(items):map(function(i) return i.label end):totable()

	eq(true, vim.list_contains(labels, "+myproject"))
	eq(true, vim.list_contains(labels, "+otherproj"))
end

T["completion"]["shows all contexts from buffer"] = function()
	utils.setup_lsp_test(child, { "@home Task one", "@work Task two" })
	utils.call_lsp_handler(child, "textDocument/completion", {
		textDocument = { uri = "" },
		position = { line = 0, character = 0 },
	})

	local items = child.lua_get("_G.lsp_result.items")
	local labels = vim.iter(items):map(function(i) return i.label end):totable()

	eq(true, vim.list_contains(labels, "@home"))
	eq(true, vim.list_contains(labels, "@work"))
end

T["completion"]["shows all key: prefixes from buffer"] = function()
	utils.setup_lsp_test(child, { "due:2025-01-01 Task one", "effort:2h Task two" })
	utils.call_lsp_handler(child, "textDocument/completion", {
		textDocument = { uri = "" },
		position = { line = 0, character = 0 },
	})

	local items = child.lua_get("_G.lsp_result.items")
	local labels = vim.iter(items):map(function(i) return i.label end):totable()

	eq(true, vim.list_contains(labels, "due:"))
	eq(true, vim.list_contains(labels, "effort:"))
end

T["completion"]["@ trigger restricts to contexts only"] = function()
	utils.setup_lsp_test(child, { "@home Task one", "+myproject Task two", "due:2025-01-01 Task three" })
	utils.call_lsp_handler(child, "textDocument/completion", {
		textDocument = { uri = "" },
		position = { line = 0, character = 0 },
		context = { triggerCharacter = "@" },
	})

	local items = child.lua_get("_G.lsp_result.items")
	local labels = vim.iter(items):map(function(i) return i.label end):totable()

	eq(true, vim.list_contains(labels, "@home"))
	eq(false, vim.list_contains(labels, "+myproject"))
	eq(false, vim.list_contains(labels, "due:"))
end

T["completion"]["+ trigger restricts to projects only"] = function()
	utils.setup_lsp_test(child, { "@home Task one", "+myproject Task two", "due:2025-01-01 Task three" })
	utils.call_lsp_handler(child, "textDocument/completion", {
		textDocument = { uri = "" },
		position = { line = 0, character = 0 },
		context = { triggerCharacter = "+" },
	})

	local items = child.lua_get("_G.lsp_result.items")
	local labels = vim.iter(items):map(function(i) return i.label end):totable()

	eq(true, vim.list_contains(labels, "+myproject"))
	eq(false, vim.list_contains(labels, "@home"))
	eq(false, vim.list_contains(labels, "due:"))
end

T["completion"]["( trigger restricts to priorities only"] = function()
	utils.setup_lsp_test(child, { "(A) Task one", "@home Task two", "+myproject Task three" })
	utils.call_lsp_handler(child, "textDocument/completion", {
		textDocument = { uri = "" },
		position = { line = 0, character = 0 },
		context = { triggerCharacter = "(" },
	})

	local items = child.lua_get("_G.lsp_result.items")
	local labels = vim.iter(items):map(function(i) return i.label end):totable()

	eq(true, vim.list_contains(labels, "(A)"))
	eq(false, vim.list_contains(labels, "@home"))
	eq(false, vim.list_contains(labels, "+myproject"))
end

T["completion"]["deduplicates repeated tags"] = function()
	utils.setup_lsp_test(child, { "+proj Task one", "+proj Task two" })
	utils.call_lsp_handler(child, "textDocument/completion", {
		textDocument = { uri = "" },
		position = { line = 0, character = 0 },
	})

	local items = child.lua_get("_G.lsp_result.items")
	local count = vim.iter(items):filter(function(i) return i.label == "+proj" end):totable()
	eq(1, #count)
end

T["completion"]["returns priorities even for empty buffer"] = function()
	utils.setup_lsp_test(child, {})
	utils.call_lsp_handler(child, "textDocument/completion", {
		textDocument = { uri = "" },
		position = { line = 0, character = 0 },
	})

	local items = child.lua_get("_G.lsp_result.items")
	local labels = vim.iter(items):map(function(i) return i.label end):totable()

	eq(true, vim.list_contains(labels, "(A)"))
	eq(true, vim.list_contains(labels, "(B)"))
	eq(true, vim.list_contains(labels, "(C)"))
end

T["formatting"] = test.new_set()

T["formatting"]["reorders incomplete task to canonical form"] = function()
	utils.setup_lsp_test(child, { "desc +proj @ctx" })
	utils.call_lsp_handler(child, "textDocument/formatting", {
		textDocument = { uri = "" },
	})

	local edits = child.lua_get("_G.lsp_result")
	eq(1, #edits)
	eq("desc @ctx +proj", edits[1].newText)
end

T["formatting"]["reorders completed task to canonical form"] = function()
	utils.setup_lsp_test(child, { "x 2025-06-15 2025-01-01 desc +proj @ctx" })
	utils.call_lsp_handler(child, "textDocument/formatting", {
		textDocument = { uri = "" },
	})

	local edits = child.lua_get("_G.lsp_result")
	eq(1, #edits)
	eq("x 2025-06-15 2025-01-01 desc @ctx +proj", edits[1].newText)
end

T["formatting"]["preserves priority in canonical order"] = function()
	utils.setup_lsp_test(child, { "(A) 2025-01-01 +proj desc @ctx" })
	utils.call_lsp_handler(child, "textDocument/formatting", {
		textDocument = { uri = "" },
	})

	local edits = child.lua_get("_G.lsp_result")
	eq(1, #edits)
	eq("(A) 2025-01-01 desc @ctx +proj", edits[1].newText)
end

T["formatting"]["preserves done priority in canonical order"] = function()
	utils.setup_lsp_test(child, { "x (A) 2025-06-15 2025-01-01 +proj desc @ctx" })
	utils.call_lsp_handler(child, "textDocument/formatting", {
		textDocument = { uri = "" },
	})

	local edits = child.lua_get("_G.lsp_result")
	eq(1, #edits)
	eq("x (A) 2025-06-15 2025-01-01 desc @ctx +proj", edits[1].newText)
end

T["formatting"]["preserves key:value pairs in canonical order"] = function()
	utils.setup_lsp_test(child, { "(A) 2025-01-01 desc due:2025-06-01 +proj @ctx" })
	utils.call_lsp_handler(child, "textDocument/formatting", {
		textDocument = { uri = "" },
	})

	local edits = child.lua_get("_G.lsp_result")
	eq(1, #edits)
	eq("(A) 2025-01-01 desc due:2025-06-01 @ctx +proj", edits[1].newText)
end

T["formatting"]["collapses extra whitespace"] = function()
	utils.setup_lsp_test(child, { "(A)  2025-01-01   Test   task   +proj   @ctx" })
	utils.call_lsp_handler(child, "textDocument/formatting", {
		textDocument = { uri = "" },
	})

	local edits = child.lua_get("_G.lsp_result")
	eq(1, #edits)
	eq("(A) 2025-01-01 Test task @ctx +proj", edits[1].newText)
end

T["formatting"]["emits no edits for already canonical line"] = function()
	utils.setup_lsp_test(child, { "(A) 2025-01-01 desc @ctx +proj" })
	utils.call_lsp_handler(child, "textDocument/formatting", {
		textDocument = { uri = "" },
	})

	local edits = child.lua_get("_G.lsp_result")
	eq(0, #edits)
end

T["formatting"]["skips empty lines without errors"] = function()
	utils.setup_lsp_test(child, { "", "+proj 2025-01-01 desc @ctx" })
	utils.call_lsp_handler(child, "textDocument/formatting", {
		textDocument = { uri = "" },
	})

	local edits = child.lua_get("_G.lsp_result")
	eq(1, #edits)
	eq("2025-01-01 desc @ctx +proj", edits[1].newText)
end

T["code_action"] = test.new_set()

T["code_action"]["returns all expected action commands"] = function()
	utils.setup_lsp_test(child, { "Test task" })
	utils.call_lsp_handler(child, "textDocument/codeAction", {
		textDocument = { uri = "" },
		range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
	})

	local actions = child.lua_get("_G.lsp_result")
	local titles = vim.iter(actions):map(function(a) return a.title end):totable()

	eq(true, vim.list_contains(titles, "Toggle done"))
	eq(true, vim.list_contains(titles, "Cycle priority"))
	eq(true, vim.list_contains(titles, "Sort tasks"))
	eq(true, vim.list_contains(titles, "Sort by priority"))
	eq(true, vim.list_contains(titles, "Sort by project"))
	eq(true, vim.list_contains(titles, "Sort by context"))
	eq(true, vim.list_contains(titles, "Sort by due date"))
end

T["execute_command"] = test.new_set()

T["execute_command"]["toggle done marks task as completed"] = function()
	utils.setup_lsp_test(child, { "(A) 2025-01-01 Test task" })
	utils.call_lsp_handler(child, "workspace/executeCommand", {
		command = "todotxt.toggle_done",
		arguments = {},
	})

	local lines = utils.get_buffer_content(child)
	eq(true, lines[1]:match("^x ") ~= nil)
end

T["execute_command"]["cycle priority advances to next letter"] = function()
	utils.setup_lsp_test(child, { "(A) 2025-01-01 Test task" })
	utils.call_lsp_handler(child, "workspace/executeCommand", {
		command = "todotxt.cycle_priority",
		arguments = {},
	})

	local lines = utils.get_buffer_content(child)
	eq("(B) 2025-01-01 Test task", lines[1])
end

T["code_action"]["includes metadata sort commands when configured"] = function()
	local tasks = { "Task tag:alpha", "Task tag:gamma", "Task tag:beta" }
	local todo_path, done_path = utils.create_temp_file_paths(child, "todo.txt", "done.txt")
	utils.create_test_todo_file(child, todo_path, tasks)

	child.lua(string.format([[
		M = require('todotxt')
		M.setup({ todotxt = %q, donetxt = %q, metadata = { tag = { sort = 'asc' } } })
		M.toggle_todotxt()
	]], todo_path, done_path))

	utils.call_lsp_handler(child, "textDocument/codeAction", {
		textDocument = { uri = "" },
		range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
	})

	local actions = child.lua_get("_G.lsp_result")
	local titles = vim.iter(actions):map(function(a) return a.title end):totable()

	eq(true, vim.list_contains(titles, "Sort by tag"))
end

T["execute_command"]["dispatches metadata sort by key"] = function()
	local tasks = { "Task tag:gamma", "Task tag:alpha", "Task tag:beta" }
	local todo_path, done_path = utils.create_temp_file_paths(child, "todo.txt", "done.txt")
	utils.create_test_todo_file(child, todo_path, tasks)

	child.lua(string.format([[
		M = require('todotxt')
		M.setup({ todotxt = %q, donetxt = %q, metadata = { tag = { sort = 'asc' } } })
		M.toggle_todotxt()
	]], todo_path, done_path))

	utils.call_lsp_handler(child, "workspace/executeCommand", {
		command = "todotxt.sort.metadata.tag",
		arguments = {},
	})

	local lines = utils.get_buffer_content(child)
	eq("Task tag:alpha", lines[1])
	eq("Task tag:beta", lines[2])
	eq("Task tag:gamma", lines[3])
end

T["execute_command"]["unconfigured metadata key is a silent no-op"] = function()
	utils.setup_lsp_test(child, { "Zebra", "Alpha" })
	utils.call_lsp_handler(child, "workspace/executeCommand", {
		command = "todotxt.sort.metadata.unknown",
		arguments = {},
	})

	-- Should not crash; buffer order unchanged
	local lines = utils.get_buffer_content(child)
	eq("Zebra", lines[1])
	eq("Alpha", lines[2])
end

T["references"] = test.new_set()

T["references"]["finds all lines with matching project tag"] = function()
	utils.setup_lsp_test(child, { "+proj Task one", "+proj Task two", "+other Task three" })
	utils.call_lsp_handler(child, "textDocument/references", {
		textDocument = { uri = "" },
		position = { line = 0, character = 0 },
	})

	local result = child.lua_get("_G.lsp_result")
	eq(2, #result)
end

T["references"]["returns empty when no tag under cursor"] = function()
	utils.setup_lsp_test(child, { "Just a task" })
	utils.call_lsp_handler(child, "textDocument/references", {
		textDocument = { uri = "" },
		position = { line = 0, character = 5 },
	})

	local result = child.lua_get("_G.lsp_result")
	eq(0, #result)
end

-- Prepare rename -------------------------------------------------------------

T["prepare_rename"] = test.new_set()

T["prepare_rename"]["returns range for project tag under cursor"] = function()
	utils.setup_lsp_test(child, { "+oldproj Task one" })
	utils.call_lsp_handler(child, "textDocument/prepareRename", {
		textDocument = { uri = "" },
		position = { line = 0, character = 0 },
	})

	local result = child.lua_get("_G.lsp_result")
	eq("table", type(result))
	eq(0, result.start.line)
	eq(0, result.start.character)
	eq(0, result["end"].line)
	eq(8, result["end"].character)
end

T["prepare_rename"]["returns nil when no tag under cursor"] = function()
	utils.setup_lsp_test(child, { "Just a task" })
	utils.call_lsp_handler(child, "textDocument/prepareRename", {
		textDocument = { uri = "" },
		position = { line = 0, character = 5 },
	})

	local result = child.lua_get("_G.lsp_result")
	eq(vim.NIL, result)
end

T["rename"] = test.new_set()

T["rename"]["renames all occurrences of a project tag"] = function()
	utils.setup_lsp_test(child, { "+oldproj Task one", "+oldproj Task two", "+otherproj Task three" })
	utils.call_lsp_handler(child, "textDocument/rename", {
		textDocument = { uri = "" },
		position = { line = 0, character = 0 },
		newName = "newproj",
	})

	local changes = child.lua_get("_G.lsp_result.changes")
	local edits = nil
	for _, v in pairs(changes) do
		edits = v
	end
	eq(2, #edits)
	eq("+newproj", edits[1].newText)
	eq("+newproj", edits[2].newText)
end

T["rename"]["rejects names with spaces"] = function()
	utils.setup_lsp_test(child, { "+oldproj Task one" })
	utils.call_lsp_handler(child, "textDocument/rename", {
		textDocument = { uri = "" },
		position = { line = 0, character = 0 },
		newName = "bad name",
	})

	local err = child.lua_get("_G.lsp_err")
	eq(1, err.code)
end

T["rename"]["rejects empty new name"] = function()
	utils.setup_lsp_test(child, { "+oldproj Task one" })
	utils.call_lsp_handler(child, "textDocument/rename", {
		textDocument = { uri = "" },
		position = { line = 0, character = 0 },
		newName = "",
	})

	local err = child.lua_get("_G.lsp_err")
	eq(1, err.code)
end

T["rename"]["strips + or @ prefix from new name"] = function()
	utils.setup_lsp_test(child, { "+oldproj Task one" })
	utils.call_lsp_handler(child, "textDocument/rename", {
		textDocument = { uri = "" },
		position = { line = 0, character = 0 },
		newName = "+newproj",
	})

	local changes = child.lua_get("_G.lsp_result.changes")
	local edits = nil
	for _, v in pairs(changes) do
		edits = v
	end
	eq(1, #edits)
	eq("+newproj", edits[1].newText)
end

T["rename"]["returns nil when no tag under cursor"] = function()
	utils.setup_lsp_test(child, { "Just a task" })
	utils.call_lsp_handler(child, "textDocument/rename", {
		textDocument = { uri = "" },
		position = { line = 0, character = 5 },
		newName = "newname",
	})

	local result = child.lua_get("_G.lsp_result")
	eq(vim.NIL, result)
end

T["initialize"] = test.new_set()

T["initialize"]["declares all server capabilities"] = function()
	utils.setup_lsp_test(child, { "test" })
	utils.call_lsp_handler(child, "initialize", { capabilities = {} })

	local result = child.lua_get("_G.lsp_result")
	eq(true, result.capabilities.completionProvider ~= nil)
	eq(true, result.capabilities.documentFormattingProvider)
	eq(true, result.capabilities.codeActionProvider)
	eq(true, result.capabilities.referencesProvider)
	eq(true, result.capabilities.renameProvider.prepareProvider)
	eq("todotxt", result.serverInfo.name)
end

return T
