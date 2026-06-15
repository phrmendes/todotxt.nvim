local bufnr = vim.api.nvim_get_current_buf()

vim.keymap.set("n", "q", function()
	pcall(function() vim.cmd("silent write!") end)
	vim.cmd("quit")
end, { buffer = bufnr, desc = "Close floating window" })

vim.keymap.set("n", "<Plug>(TodoTxtToggleState)", function() require("todotxt").toggle_todo_state() end, {
	noremap = true,
	buffer = bufnr,
	desc = "Toggle todo state",
})

vim.keymap.set("n", "<Plug>(TodoTxtCyclePriority)", function() require("todotxt").cycle_priority() end, {
	noremap = true,
	buffer = bufnr,
	desc = "Cycle priority",
})

vim.keymap.set("n", "<Plug>(TodoTxtSortTasks)", function() require("todotxt").sort_tasks() end, {
	noremap = true,
	buffer = bufnr,
	desc = "Sort tasks",
})

vim.keymap.set("n", "<Plug>(TodoTxtSortByPriority)", function() require("todotxt").sort_tasks_by_priority() end, {
	noremap = true,
	buffer = bufnr,
	desc = "Sort by priority",
})

vim.keymap.set("n", "<Plug>(TodoTxtSortByProject)", function() require("todotxt").sort_tasks_by_project() end, {
	noremap = true,
	buffer = bufnr,
	desc = "Sort by project",
})

vim.keymap.set("n", "<Plug>(TodoTxtSortByContext)", function() require("todotxt").sort_tasks_by_context() end, {
	noremap = true,
	buffer = bufnr,
	desc = "Sort by context",
})

vim.keymap.set("n", "<Plug>(TodoTxtSortByDueDate)", function() require("todotxt").sort_tasks_by_due_date() end, {
	noremap = true,
	buffer = bufnr,
	desc = "Sort by due date",
})

vim.keymap.set("n", "<Plug>(TodoTxtMoveDone)", function() require("todotxt").move_done_tasks() end, {
	noremap = true,
	buffer = bufnr,
	desc = "Move done tasks",
})

local metadata = require("todotxt").config.metadata or {}

for key, _ in pairs(metadata) do
	local plug_name = "<Plug>(TodoTxtSortBy" .. key:gsub("^%l", string.upper) .. ")"

	vim.keymap.set(
		"n",
		plug_name,
		function() require("todotxt").sort_by_metadata(key) end,
		{ noremap = true, buffer = bufnr, desc = "Sort by " .. key }
	)
end
