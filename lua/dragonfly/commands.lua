local commands = {}

local state = require("dragonfly.state")
local buffer_ui = require("dragonfly.buffer_ui")
local project_ui = require("dragonfly.project_ui")

--- Sets up global autocommands required by Dragonfly.
---
---@return nil
function commands.create_autocommands()
	vim.api.nvim_create_autocmd({ "InsertEnter", "CmdLineEnter" }, {
		callback = function()
			if not state.is_searching then
				vim.opt.hlsearch = false
				buffer_ui.close()
			end
		end
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		callback = function()
			if project_ui.is_open() then
				project_ui.perform_search()
			end
		end
	})

	vim.api.nvim_create_autocmd("BufUnload", {
		callback = function()
			local all_buffers = vim.api.nvim_list_bufs()
			for _, buffer in ipairs(all_buffers) do
				if vim.api.nvim_buf_is_loaded(buffer) and vim.api.nvim_get_option_value("filetype", { buf = buffer }) ~= "dragonfly" then
					return
				end
			end

			vim.cmd("quit")
		end
	})
end

--- Creates the Dragonfly user commands.
---
---@return nil
function commands.create_user_commands()
	vim.api.nvim_create_user_command("DragonflyProjectReplace", function()
		state.replace = true
		project_ui.open_window()
	end, {})

	vim.api.nvim_create_user_command("DragonflyProject", function()
		state.replace = false
		project_ui.open_window()
	end, {})

	vim.api.nvim_create_user_command("DragonflyBuffer", function()
		state.replace = false
		buffer_ui.open()
	end, {})

	vim.api.nvim_create_user_command("DragonflyBufferReplace", function()
		state.replace = true
		buffer_ui.open()
	end, {})
end

return commands
