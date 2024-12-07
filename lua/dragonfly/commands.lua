local commands = {}

local state = require("dragonfly.state")
local buffer_ui = require("dragonfly.buffer_ui")
local project_ui = require("dragonfly.project_ui")

function commands.create_autocommands()
	vim.api.nvim_create_autocmd({ "InsertEnter", "CmdwinEnter" }, {
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
end

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
		buffer_ui.open_window()
	end, {})

	vim.api.nvim_create_user_command("DragonflyBufferReplace", function()
		state.replace = true
		buffer_ui.open_window()
	end, {})
end

return commands
