local public = {}

require("dragonfly.api")

local ui = require("dragonfly.ui")
local config = require("dragonfly.config")
local state = require("dragonfly.state")

function public.setup(options)
	local normal_float_bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("NormalFloat")), "bg#")
	local float_border_fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("FloatBorder")), "fg#")
	vim.api.nvim_set_hl(0, 'FloatBorder', { bg = normal_float_bg, fg = float_border_fg })

	config.set_options(options)
	vim.api.nvim_create_user_command("Dragonfly", ui.open_window, {})
	vim.api.nvim_create_user_command("DragonflyNoReplace", function()
		state.replace = false
		ui.open_window()
	end, {})
end

return public
