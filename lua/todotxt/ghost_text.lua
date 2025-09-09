local patterns = require("todotxt.patterns")
local utils = require("todotxt.utils")

local ghost_text = {}

local default_config = {
	enable = false,
	mappings = {
		["(A)"] = "now",
		["(B)"] = "next",
		["(C)"] = "today",
		["(D)"] = "tomorrow",
		["(E)"] = "this week",
		["(F)"] = "next week"
	},
	prefix = " ",
	highlight = "Comment"
}

local config = {}
local ns_id = nil

--- @param opts table Configuration options
ghost_text.setup = function(opts)
	config = vim.tbl_deep_extend("force", default_config, opts or {})

	if config.enable then
		ns_id = vim.api.nvim_create_namespace("todotxt_ghost_text")
		ghost_text.create_autocmds()
	end
end

ghost_text.update = function()
	if not config.enable or not ns_id then
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	for i, line in ipairs(lines) do
		for pattern, ghost_text_content in pairs(config.mappings) do
			-- Escape special regex characters in pattern
			local escaped_pattern = pattern:gsub("[%(%)%[%]%.%+%-%*%?%^%$]", "%%%1")

			if line:match("^%s*" .. escaped_pattern) then
				vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
					virt_text = { { config.prefix .. ghost_text_content, config.highlight } },
					virt_text_pos = "eol"
				})
				break
			end
		end
	end
end

ghost_text.create_autocmds = function()
	local augroup = vim.api.nvim_create_augroup("TodoTxtGhostText", { clear = true })

	vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
		group = augroup,
		pattern = { "*.txt" },
		callback = function()
			-- Only apply to todotxt files
			local bufname = vim.api.nvim_buf_get_name(0)
			if bufname:match("todo%.txt$") or bufname:match("done%.txt$") or vim.bo.filetype == "todotxt" then
				ghost_text.update()
			end
		end,
	})
end

ghost_text.enable = function()
	config.enable = true
	if not ns_id then
		ns_id = vim.api.nvim_create_namespace("todotxt_ghost_text")
		ghost_text.create_autocmds()
	end
	ghost_text.update()
end

ghost_text.disable = function()
	config.enable = false
	if ns_id then
		local bufnr = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
	end
end

ghost_text.toggle = function()
	if config.enable then
		ghost_text.disable()
	else
		ghost_text.enable()
	end
end

return ghost_text
