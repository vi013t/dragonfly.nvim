local state = require("dragonfly.state")

local config = {}

local default_options = {
	on_close = function() end,
	on_open = function() end,
	default_search_options = {
		case_sensitive = false,
		regex = false,
	}
}

function config.set_options(options)
	config.options = vim.tbl_extend("force", default_options, options)
	state.search_options = config.options.default_search_options
end

return config
