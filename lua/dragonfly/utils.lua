local utils = {}

function utils.exit_insert_mode()
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'i', false)
	vim.opt.hlsearch = true
end

return utils
