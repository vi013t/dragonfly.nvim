local state = require("dragonfly.state")

---@alias DragonflyConfig { on_close: fun(), on_open: fun(), default_search_options: { case_sensitive: boolean, regex: boolean } }
---@alias PartialDragonflyConfig { on_close?: fun(), on_open?: fun(), default_search_options?: { case_sensitive?: boolean, regex?: boolean } }

local config = {}

--- The default config for `dragonfly.nvim`.
---
---@type DragonflyConfig
local default_options = {
	on_close = function() end,
	on_open = function() end,
	default_search_options = {
		case_sensitive = true,
		regex = false,
		whole_word = false,
	},
	ignore = {
		"gitignored",
		"dotfiles",
	}
}

--- Sets the config from the user, replacing missing values with their defaults.
---
---@param options PartialDragonflyConfig
---
---@return nil
function config.set_options(options)
	config.options = vim.tbl_extend("force", default_options, options)
	state.search_options = config.options.default_search_options
end

return config
