local config = {}

local default_options = {
	on_close = function() end,
	on_open = function() end
}

function config.set_options(options)
	config.options = vim.tbl_extend("force", default_options, options)
end

return config
