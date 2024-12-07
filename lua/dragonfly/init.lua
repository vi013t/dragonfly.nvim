local public = {}

require("dragonfly.api")

local ui = require("dragonfly.ui")
local buffer_ui = require("dragonfly.buffer_ui")
local config = require("dragonfly.config")
local state = require("dragonfly.state")

function public.setup(options)
	config.set_options(options)

	local normal_float_bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("NormalFloat")), "bg#")
	local float_border_fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("FloatBorder")), "fg#")
	vim.api.nvim_set_hl(0, 'FloatBorder', { bg = normal_float_bg, fg = float_border_fg })

	vim.api.nvim_create_autocmd("InsertEnter", {
		callback = function()
			if not state.is_searching then
				vim.opt.hlsearch = false
				buffer_ui.close()
			end
		end
	})

	vim.api.nvim_create_user_command("DragonflyProjectReplace", function()
		state.replace = true
		ui.open_window()
	end, {})

	vim.api.nvim_create_user_command("DragonflyProject", function()
		state.replace = false
		ui.open_window()
	end, {})

	vim.api.nvim_create_user_command("DragonflyBuffer", function()
		state.replace = false
		buffer_ui.open_window()
	end, {})

	vim.api.nvim_create_user_command("DragonflyBufferReplace", function()
		state.replace = true
		buffer_ui.open_window()
	end, {})

	vim.api.nvim_create_autocmd("BufWritePost", {
		callback = function()
			if ui.is_open() then
				ui.perform_search()
			end
		end
	})
end

return public
