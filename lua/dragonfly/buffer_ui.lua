local buffer_ui = {}

local state = require("dragonfly.state")
local utils = require("dragonfly.utils")

function buffer_ui.open_window()
	buffer_ui.close()

	vim.opt.hlsearch = true
	state.is_searching = true
	state.previous_window = vim.api.nvim_get_current_win()
	state.previous_buffer = vim.api.nvim_get_current_buf()

	local vim_width = vim.api.nvim_get_option_value("columns", { scope = "global" })

	buffer_ui.search_buffer = vim.api.nvim_create_buf(false, true)
	buffer_ui.search_window = vim.api.nvim_open_win(buffer_ui.search_buffer, true, {
		relative = "win",
		width = 30,
		height = 1,
		border = "rounded",
		style = "minimal",
		row = 0,
		col = vim_width,
		anchor = "NE",
		title = " Search "
	})
	local bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("Normal")), "bg#")
	local fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("FloatBorder")), "fg#")
	vim.api.nvim_set_hl(0, "DragonflySearchboxBorder", { fg = fg, bg = bg })
	vim.api.nvim_set_option_value("winhighlight",
		"Normal:Normal,NormalNC:Normal,FloatBorder:DragonflySearchboxBorder,Search:Normal",
		{ win = buffer_ui.search_window }
	)

	vim.api.nvim_create_autocmd("TextChangedI", {
		buffer = buffer_ui.search_buffer,
		callback = function()
			buffer_ui.search_string = vim.api.nvim_buf_get_lines(buffer_ui.search_buffer, 0, 1, true)[1]
			vim.fn.setreg("/", buffer_ui.search_string)
		end
	})

	vim.keymap.set("i", "<CR>", function()
		if state.replace then
			vim.api.nvim_set_current_win(buffer_ui.replace_window)
			vim.api.nvim_set_current_buf(buffer_ui.replace_buffer)
		else
			vim.api.nvim_set_current_win(state.previous_window)
			vim.api.nvim_set_current_buf(state.previous_buffer)
			utils.exit_insert_mode()
			vim.api.nvim_feedkeys("n", "n", true)
			state.is_searching = false
		end
	end, { buffer = buffer_ui.search_buffer })

	vim.keymap.set("i", "<Tab>", function()
		if state.replace then
			vim.api.nvim_set_current_win(buffer_ui.replace_window)
			vim.api.nvim_set_current_buf(buffer_ui.replace_buffer)
		end
	end, { buffer = buffer_ui.search_buffer })

	vim.keymap.set("i", "<S-Tab>", function()
		if state.replace then
			vim.api.nvim_set_current_win(buffer_ui.replace_window)
			vim.api.nvim_set_current_buf(buffer_ui.replace_buffer)
		end
	end, { buffer = buffer_ui.search_buffer })

	vim.keymap.set("i", "<Esc>", function()
		buffer_ui.close()
		utils.exit_insert_mode()
		state.is_searching = false
		if state.replace then
			vim.opt.hlsearch = false
		end
	end, { buffer = buffer_ui.search_buffer })

	vim.api.nvim_command("startinsert")

	if state.replace then
		buffer_ui.replace_buffer = vim.api.nvim_create_buf(false, true)
		buffer_ui.replace_window = vim.api.nvim_open_win(buffer_ui.replace_buffer, false, {
			relative = "win",
			width = 30,
			height = 1,
			border = "rounded",
			style = "minimal",
			row = 2,
			col = vim_width,
			anchor = "NE",
			title = " Replace "
		})
		vim.api.nvim_set_option_value("winhighlight",
			"Normal:Normal,NormalNC:Normal,FloatBorder:DragonflySearchboxBorder,Search:Normal",
			{ win = buffer_ui.replace_window }
		)

		vim.api.nvim_create_autocmd("TextChangedI", {
			buffer = buffer_ui.replace_buffer,
			callback = function()
				buffer_ui.replace_string = vim.api.nvim_buf_get_lines(buffer_ui.replace_buffer, 0, 1, true)[1]
			end
		})

		vim.keymap.set("i", "<CR>", function()
			vim.api.nvim_set_current_win(state.previous_window)
			vim.api.nvim_set_current_buf(state.previous_buffer)
			utils.exit_insert_mode()
			state.is_searching = false
			buffer_ui.close()
			vim.cmd("%sno/" .. buffer_ui.search_string .. "/" .. buffer_ui.replace_string .. "/g")
			vim.opt.hlsearch = false
		end, { buffer = buffer_ui.replace_buffer })

		vim.keymap.set("i", "<S-Tab>", function()
			if state.replace then
				vim.api.nvim_set_current_win(buffer_ui.search_window)
				vim.api.nvim_set_current_buf(buffer_ui.search_buffer)
			end
		end, { buffer = buffer_ui.replace_buffer })

		vim.keymap.set("i", "<Tab>", function()
			if state.replace then
				vim.api.nvim_set_current_win(buffer_ui.search_window)
				vim.api.nvim_set_current_buf(buffer_ui.search_buffer)
			end
		end, { buffer = buffer_ui.replace_buffer })

		vim.keymap.set("i", "<Esc>", function()
			buffer_ui.close()
			utils.exit_insert_mode()
			state.is_searching = false
			vim.opt.hlsearch = false
		end, { buffer = buffer_ui.replace_buffer })
	end
end

function buffer_ui.close()
	pcall(function()
		vim.api.nvim_buf_delete(buffer_ui.search_buffer, { force = true })
		vim.api.nvim_buf_delete(buffer_ui.replace_buffer, { force = true })
	end)
end

return buffer_ui
