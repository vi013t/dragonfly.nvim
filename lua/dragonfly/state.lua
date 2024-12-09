--- Global state data for the plugin.
---
---DragonflyActive { replace: boolean, search_options: { case_sensitive: boolean, regex: boolean, whole_word: boolean }, previous_buffer?: number, previous_window: integer | nil, is_searching: boolean }
local state = {
	replace = true,
	search_options = {
		case_sensitive = true,
		regex = false,
		whole_word = false,
	},
	previous_window = nil,
	previous_buffer = nil,
	is_searching = false,
}

return state
