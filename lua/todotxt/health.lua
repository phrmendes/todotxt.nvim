---
--- Health check for todotxt.nvim plugin
---

local health = {}

function health.check()
	vim.health.start("todotxt.nvim")

	if vim.g.loaded_todotxt then
		vim.health.ok("Plugin is loaded")
	else
		vim.health.error("Plugin not loaded")
		return
	end

	local todotxt = package.loaded["todotxt"]

	if not todotxt or not todotxt.config or not todotxt.config.todotxt then
		vim.health.warn("Plugin not configured - run require('todotxt').setup()")
		return
	end

	local config = todotxt.config

	local ok, err = pcall(vim.validate, {
		todotxt = { config.todotxt, "string" },
		donetxt = { config.donetxt, "string" },
	})

	if ok then
		vim.health.ok("Configuration is valid")
	else
		vim.health.error("Configuration validation failed: " .. err)
		return
	end

	if vim.fn.filereadable(config.todotxt) == 1 then
		vim.health.ok("todo.txt file exists: " .. config.todotxt)
	else
		vim.health.warn("todo.txt file not found: " .. config.todotxt)
	end

	if vim.fn.filereadable(config.donetxt) == 1 then
		vim.health.ok("done.txt file exists: " .. config.donetxt)
	else
		vim.health.warn("done.txt file not found: " .. config.donetxt)
	end

	local has_ts, ts_parsers = pcall(require, "nvim-treesitter.parsers")
	if has_ts and ts_parsers.has_parser("todotxt") then
		vim.health.ok("todotxt treesitter parser is available")
	else
		vim.health.warn("todotxt treesitter parser not available - install with :TSInstall todotxt")
	end
end

return health
