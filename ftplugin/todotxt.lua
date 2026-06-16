local bufnr = vim.api.nvim_get_current_buf()

vim.keymap.set("n", "q", function()
	pcall(function() vim.cmd("silent write!") end)
	vim.cmd("quit")
end, { buffer = bufnr, desc = "Close floating window" })
