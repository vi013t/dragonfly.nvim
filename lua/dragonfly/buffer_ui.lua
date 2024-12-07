local buffer_ui = {}

local state = require("dragonfly.state")
local utils = require("dragonfly.utils")

local function create_search_options_window()
	buffer_ui.search_options_buffer = vim.api.nvim_create_buf(false, true)
	buffer_ui.search_options_window = vim.api.nvim_open_win(buffer_ui.search_options_buffer, false, {
		relative = "win",
		win = buffer_ui.search_window,
		row = 0,
		col = 30 - 6,
		width = 6,
		height = 1,
		style = "minimal",
		zindex = 999
	})

	vim.api.nvim_set_option_value("winhighlight",
		"Normal:Normal,NormalNC:Normal,FloatBorder:DragonflySearchboxBorder,Search:Normal,CurSearch:Normal",
		{ win = buffer_ui.search_options_window }
	)

	-- Toggle case sensitive
	vim.keymap.set("i", "<C-c>", function()
		state.search_options.case_sensitive = not state.search_options.case_sensitive
		buffer_ui.perform_search()
	end, { buffer = buffer_ui.search_buffer })

	-- Toggle regex
	vim.keymap.set("i", "<C-r>", function()
		state.search_options.regex = not state.search_options.regex
		buffer_ui.perform_search()
	end, { buffer = buffer_ui.search_buffer })
end

function buffer_ui.perform_search()
	buffer_ui.search_string = vim.api.nvim_buf_get_lines(buffer_ui.search_buffer, 0, 1, true)[1]
	local search_string = ""
	if state.search_options.regex then
		search_string = search_string .. "\\v"
	else
		search_string = search_string .. "\\V"
	end
	if state.search_options.case_sensitive then
		search_string = search_string .. "\\C"
	else
		search_string = search_string .. "\\c"
	end
	search_string = search_string .. buffer_ui.search_string
	vim.fn.setreg("/", search_string)
	buffer_ui.redraw()
end

function buffer_ui.redraw()
	vim.api.nvim_buf_set_lines(buffer_ui.search_options_buffer, 0, 1, true, { "Aa .* " })

	local case_sensitive_highlight = "@comment"
	if state.search_options.case_sensitive then case_sensitive_highlight = "@type" end
	vim.api.nvim_buf_add_highlight(buffer_ui.search_options_buffer, -1, case_sensitive_highlight, 0, 0, 2)

	local regex_highlight = "@comment"
	if state.search_options.regex then regex_highlight = "@type" end
	vim.api.nvim_buf_add_highlight(buffer_ui.search_options_buffer, -1, regex_highlight, 0, 3, -1)
end

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
		"Normal:Normal,NormalNC:Normal,FloatBorder:DragonflySearchboxBorder,Search:Normal,CurSearch:Normal",
		{ win = buffer_ui.search_window }
	)

	vim.api.nvim_create_autocmd("TextChangedI", {
		buffer = buffer_ui.search_buffer,
		callback = buffer_ui.perform_search
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

	create_search_options_window()

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

	buffer_ui.redraw()
end

function buffer_ui.close()
	pcall(function()
		vim.api.nvim_buf_delete(buffer_ui.search_buffer, { force = true })
		vim.api.nvim_buf_delete(buffer_ui.search_options_buffer, { force = true })
		vim.api.nvim_buf_delete(buffer_ui.replace_buffer, { force = true })
	end)
end

return buffer_ui
