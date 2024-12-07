local public = {}

require("dragonfly.api")

local config = require("dragonfly.config")
local commands = require("dragonfly.commands")
local utils = require("dragonfly.utils")

function public.setup(options)
	config.set_options(options)
	utils.setup_highlights()
	commands.create_autocommands()
	commands.create_user_commands()
end

return public
