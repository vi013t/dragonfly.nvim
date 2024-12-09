local utils = {}

local config = require("dragonfly.config")

--- Exits from insert mode into normal mode.
---
---@return nil
function utils.exit_insert_mode()
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'i', false)
	vim.opt.hlsearch = true
end

--- Sets up some highlight overrides used by Dragonfly.
---
---@return nil
function utils.setup_highlights()
	local normal_float_bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("NormalFloat")), "bg#")
	local float_border_fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("FloatBorder")), "fg#")
	vim.api.nvim_set_hl(0, 'FloatBorder', { bg = normal_float_bg, fg = float_border_fg })
	vim.api.nvim_set_hl(0, "DragonflyReplaceAll", { bg = "#AAFFAA", fg = "#000000" })
	vim.api.nvim_set_hl(0, "DragonflyReplaceAllEnd", { fg = "#AAFFAA" })

	vim.api.nvim_set_hl(0, "DragonflyActive", config.options.highlights.active)
	vim.api.nvim_set_hl(0, "DragonflyInactive", config.options.highlights.inactive)
end

function utils.reload_buffers()
	local previous_buffer = vim.api.nvim_get_current_buf()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			vim.api.nvim_set_current_buf(buf)
			vim.api.nvim_command('checktime')
		end
	end
	vim.api.nvim_set_current_buf(previous_buffer)
end

return utils
