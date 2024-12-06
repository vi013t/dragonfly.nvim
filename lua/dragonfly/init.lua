local public = {}

local ui = require("dragonfly.ui")
local config = require("dragonfly.config")

function public.setup(options)
	config.set_options(options)
	vim.api.nvim_create_user_command("Dragonfly", ui.open_window, {})
end

return public
