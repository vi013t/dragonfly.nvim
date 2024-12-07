local utils = {}

function utils.exit_insert_mode()
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'i', false)
	vim.opt.hlsearch = true
end

function utils.setup_highlights()
	local normal_float_bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("NormalFloat")), "bg#")
	local float_border_fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("FloatBorder")), "fg#")
	vim.api.nvim_set_hl(0, 'FloatBorder', { bg = normal_float_bg, fg = float_border_fg })
end

return utils
