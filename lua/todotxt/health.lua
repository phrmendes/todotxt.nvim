---
--- Health check for todotxt.nvim plugin
---
--- ==============================================================================
--- @module "todotxt.health"

local health = {}

--- Run health checks for todotxt.nvim
function health.check()
	vim.health.start("todotxt.nvim")

	local todotxt = package.loaded["todotxt"]

	if not todotxt or not todotxt.config or not todotxt.config.todotxt then
		vim.health.warn("Plugin not configured - run require('todotxt').setup()")
		return
	end

	local config = todotxt.config

	if vim.uv.fs_stat(config.todotxt) then
		vim.health.ok("todo.txt file exists: " .. config.todotxt)
	else
		vim.health.warn("todo.txt file not found: " .. config.todotxt)
	end

	if vim.uv.fs_stat(config.donetxt) then
		vim.health.ok("done.txt file exists: " .. config.donetxt)
	else
		vim.health.warn("done.txt file not found: " .. config.donetxt)
	end

	local has_ts, ts_parsers = pcall(require, "nvim-treesitter.parsers")

	if has_ts and ts_parsers.has_parser("todotxt") then
		vim.health.ok("todotxt treesitter parser is available")
		return
	end

	vim.health.warn("todotxt treesitter parser not available - install with :TSInstall todotxt")
end

return health
