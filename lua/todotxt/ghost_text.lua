---
--- Ghost text display for priority-based hints in todo.txt buffers.
---
--- ==============================================================================
--- @module "todotxt.ghost_text"

require("todotxt.types")

local parser = require("todotxt.parser")
local utils = require("todotxt.utils")

local ghost_text = {}

local default_config = {
	enable = false,
	mappings = {
		["(A)"] = "today",
		["(B)"] = "tomorrow",
		["(C)"] = "this week",
	},
	prefix = " ",
	highlight = "Comment",
	namespace_id = nil,
}

--- @type GhostTextConfig
local cfg = {}

--- Initialize ghost text module with configuration options
--- @param opts GhostTextConfig? Configuration options
--- @return nil
ghost_text.setup = function(opts)
	cfg = vim.tbl_deep_extend("force", default_config, opts or {})

	if cfg.enable then
		cfg.namespace_id = vim.api.nvim_create_namespace("todotxt_ghost_text")
		ghost_text.create_autocmds()
	end
end

--- Update ghost text display for current buffer based on priority patterns
--- @return nil
ghost_text.update = function()
	if not cfg.enable or not cfg.namespace_id then return end

	local bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(bufnr, cfg.namespace_id, 0, -1)

	local lines = utils.get_lines(bufnr)

	vim.iter(ipairs(lines)):each(function(i, line)
		local priority = parser.parse(line).priority
		if not priority then return end
		local text = cfg.mappings["(" .. priority .. ")"]
		if not text then return end

		vim.api.nvim_buf_set_extmark(bufnr, cfg.namespace_id, i - 1, 0, {
			virt_text = { { cfg.prefix .. text, cfg.highlight } },
			virt_text_pos = "eol",
		})
	end)
end

--- Create autocommands for automatic ghost text updates on todo.txt files
--- @return nil
ghost_text.create_autocmds = function()
	local augroup = vim.api.nvim_create_augroup("TodoTxtGhostText", { clear = true })

	vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
		group = augroup,
		pattern = "*.txt",
		callback = function()
			if vim.bo.filetype == "todotxt" then ghost_text.update() end
		end,
	})
end

--- Enable ghost text display and set up autocommands
--- @return nil
ghost_text.enable = function()
	cfg.enable = true

	if not cfg.namespace_id then
		cfg.namespace_id = vim.api.nvim_create_namespace("todotxt_ghost_text")
		ghost_text.create_autocmds()
	end

	ghost_text.update()
end

--- Disable ghost text display and clear existing extmarks
--- @return nil
ghost_text.disable = function()
	cfg.enable = false

	if cfg.namespace_id then
		local bufnr = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_clear_namespace(bufnr, cfg.namespace_id, 0, -1)
	end
end

--- Toggle ghost text display between enabled and disabled states
--- @return nil
ghost_text.toggle = function()
	if cfg.enable then
		ghost_text.disable()
		return
	end

	ghost_text.enable()
end

return ghost_text
