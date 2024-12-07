local ui = {}

local config = require("dragonfly.config")
local state = require("dragonfly.state")
local api = require("dragonfly.api")

ui.matches = {}

---@type (Match | boolean)[]
ui.match_lines = {}

local function exit_insert_mode()
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'i', true)
end

---@param paths SegmentedMatch[]
---
---@return MatchDirectory
local function group_paths(paths, iteration)
	iteration = iteration or 1
	local folder_entries = {}
	for _, match in ipairs(paths) do
		if #match.segments == 0 then
			table.insert(folder_entries,
				{ line = match.line, column = match.column, match = match.match, file_name = match.file_name })
			goto continue
		end

		local folder_name = match.segments[1]
		if not folder_entries[folder_name] then folder_entries[folder_name] = {} end

		table.remove(match.segments, 1)
		table.insert(folder_entries[folder_name], match)

		::continue::
	end

	for name, entry in pairs(folder_entries) do
		if type(name) == "number" then goto continue end
		folder_entries[name] = group_paths(entry, iteration + 1)
		::continue::
	end

	return folder_entries
end

---@alias Match { file_name: string, line: number, column: number, match: string }

---@alias SegmentedMatch { segments: string[], line: number, column: number, match: string, file_name: string }
---@alias MatchDirectory table<string | number, (Match | MatchDirectory)[]>

---@param results string[]
---
---@return MatchDirectory
local function group_results(results)
	---@type Match[]
	local matches = {}
	for _, result in ipairs(results) do
		local file_name, line, column, match = result:match("^([^:]+):(%d+):(%d+):(.+)")
		table.insert(matches,
			{
				file_name = assert(file_name),
				line = tonumber(assert(line)),
				column = tonumber(assert(column)),
				match = assert(match)
			})
	end

	---@type SegmentedMatch[]
	local paths = {}
	for _, match in ipairs(matches) do
		local path_segments = {}
		for segment in match.file_name:gmatch("[^\\/]+[\\/]?") do
			local path_segment = assert(segment:match("^([^\\/]+)[\\/]?"))
			table.insert(path_segments, path_segment)
		end
		table.insert(paths, {
			segments = path_segments,
			line = match.line,
			column = match.column,
			match = match.match,
			file_name = match.file_name
		})
	end

	return group_paths(paths)
end

---@param folders MatchDirectory
local function draw_folders(folders, indent)
	indent = indent or 0

	local indentation = ("│ "):rep(indent - 1)
	if indent == 0 or indent == 1 then indentation = "" end
	indentation = "  " .. indentation

	local paircount = 0

	for name, _ in pairs(folders) do
		if type(name) ~= "number" then
			paircount = paircount + 1
		end
	end

	-- Folders
	for name, contents in pairs(folders) do
		if type(name) == "number" then goto continue end

		---@cast name string

		local icon, icon_color
		if vim.islist(contents) then
			local extension = name:match("%.([^%.]+)$")
			---@cast extension string
			icon = require("nvim-web-devicons").get_icon(name, extension or name, { default = true })
			if extension then
				icon_color = "DevIcon" .. extension:sub(1, 1):upper() .. (extension:sub(2) or ""):lower()
			else
				icon_color = "DevIconTxt"
			end
		else
			icon = ""
			icon_color = "NvimTreeFolderIcon"
		end

		local line = {
			{ indentation, highlight = "@comment" }
		}

		if indent ~= 0 then
			table.insert(line, { "│ ", highlight = "@comment" })
		end

		table.insert(line, { icon, highlight = icon_color })
		table.insert(line, { " " .. name })

		vim.api.nvim_buf_append_line(ui.main_buffer, line)
		table.insert(ui.match_lines, false)

		draw_folders(contents, indent + 1)

		paircount = paircount + 1

		::continue::
	end

	-- File matches
	for index, match in ipairs(folders) do
		---@cast match Match
		local bar = "│ "
		if index == #folders then bar = "└ " end

		vim.api.nvim_buf_append_line(ui.main_buffer, {
			{ indentation .. bar .. tostring(match.line) .. ":" .. tostring(match.column) .. ": ", highlight = "@comment" },
			{ match.match,                                                                         highlight = "@type" },
		})
		table.insert(ui.match_lines, match)
	end
end

function ui.perform_search()
	ui.matches = {}
	ui.match_lines = {}
	ui.search_string = table.concat(vim.api.nvim_buf_get_lines(ui.search_buffer, 0, 1, true), "\n")
	if ui.search_string:match("^%s*$") then
		ui.redraw()
		return
	end

	-- Generate ripgrep command
	local ripgrep_command = { "rg", "--no-heading", "--vimgrep", "--color=never", "--only-matching", }
	if not state.search_options.regex then table.insert(ripgrep_command, "--fixed-strings") end
	if not state.search_options.case_sensitive then table.insert(ripgrep_command, "--ignore-case") end
	table.insert(ripgrep_command, ui.search_string)

	local output = assert(vim.system(ripgrep_command, { true }):wait().stdout)
	for line in output:gmatch("[^\r\n]+") do
		table.insert(ui.matches, line)
	end
	ui.redraw()
end

function ui.redraw()
	api.drawn_buffers = {}

	vim.api.nvim_buf_append_line(ui.main_buffer)
	vim.api.nvim_buf_append_line(ui.main_buffer, { "  Search ", highlight = "@type" })
	vim.api.nvim_buf_append_line(ui.main_buffer)
	vim.api.nvim_buf_append_line(ui.main_buffer)
	vim.api.nvim_buf_append_line(ui.main_buffer)
	vim.api.nvim_buf_append_line(ui.main_buffer)

	if state.replace then
		vim.api.nvim_buf_append_line(ui.main_buffer, { "  Replace 󰛔", highlight = "@type" })
		vim.api.nvim_buf_append_line(ui.main_buffer)
		vim.api.nvim_buf_append_line(ui.main_buffer)
		vim.api.nvim_buf_append_line(ui.main_buffer)
		vim.api.nvim_buf_append_line(ui.main_buffer)
	end

	vim.api.nvim_buf_append_line(ui.main_buffer, { "  Matches 󱨉", highlight = "@type" })
	vim.api.nvim_buf_append_line(ui.main_buffer)

	local matches = group_results(ui.matches)
	draw_folders(matches)

	vim.api.nvim_buf_append_line(ui.main_buffer)
	vim.api.nvim_buf_append_line(ui.main_buffer)

	vim.api.nvim_buf_set_lines(ui.search_options_buffer, 0, 1, true, { "Aa .* " })

	local case_sensitive_highlight = "@comment"
	if state.search_options.case_sensitive then case_sensitive_highlight = "@type" end
	vim.api.nvim_buf_add_highlight(ui.search_options_buffer, -1, case_sensitive_highlight, 0, 0, 2)

	local regex_highlight = "@comment"
	if state.search_options.regex then regex_highlight = "@type" end
	vim.api.nvim_buf_add_highlight(ui.search_options_buffer, -1, regex_highlight, 0, 3, -1)
end

local function jump_to_match()
	local line = vim.api.nvim_win_get_cursor(ui.main_window)[1]
	local blank_lines = 13
	local match = ui.match_lines[line - blank_lines]
	if not match then return end
	vim.api.nvim_set_current_win(ui.previous_window)
	vim.cmd(":e " .. match.file_name)
	vim.fn.cursor({ match.line, match.column })
end

local function create_help_window()
	ui.help_buffer = vim.api.nvim_create_buf(false, true)
	ui.help_window = vim.api.nvim_open_win(ui.help_buffer, true, {
		relative = "win",
		win = ui.search_window,
		row = 10,
		col = -1,
		width = 31,
		height = 12,
		style = "minimal",
		zindex = 9999,
		border = "rounded",
	})

	vim.keymap.set("n", "q", function()
		vim.api.nvim_buf_delete(ui.help_buffer, { force = true })
		vim.api.nvim_set_current_win(ui.search_window)
		vim.api.nvim_set_current_buf(ui.search_buffer)
		vim.api.nvim_command("startinsert")
	end, { buffer = ui.help_buffer })

	vim.api.nvim_buf_append_line(ui.help_buffer, { "Dragonfly Help", highlight = "@type" },
		{ center_in = ui.help_window })
	vim.api.nvim_buf_append_line(ui.help_buffer)
	vim.api.nvim_buf_append_line(ui.help_buffer, { { " <C-c>", highlight = "@type" }, { ": Toggle Case Sensitivity" } })
	vim.api.nvim_buf_append_line(ui.help_buffer, { { " <C-r>", highlight = "@type" }, { ": Toggle Regex Searching" } })
	vim.api.nvim_buf_append_line(ui.help_buffer, { { " <Tab>", highlight = "@type" }, { ": Next text box" } })
	vim.api.nvim_buf_append_line(ui.help_buffer, { { " <S-Tab>", highlight = "@type" }, { ": Previous text box" } })
	vim.api.nvim_buf_append_line(ui.help_buffer, { { " <Esc>", highlight = "@type" }, { ": Unfocus Dragonfly" } })
	vim.api.nvim_buf_append_line(ui.help_buffer, { { " q", highlight = "@type" }, { ": Close Dragonfly" } })
	vim.api.nvim_buf_append_line(ui.help_buffer)
	vim.api.nvim_buf_append_line(ui.help_buffer)
	vim.api.nvim_buf_append_line(ui.help_buffer, { " Press q to close this window", highlight = "@comment" })
end

local function create_main_window()
	ui.main_buffer = vim.api.nvim_create_buf(false, true)
	ui.main_window = vim.api.nvim_open_win(ui.main_buffer, false, {
		width = 35,
		style = "minimal",
		split = "left",
	})
	vim.api.nvim_set_option_value("number", false, { win = ui.main_window })
	vim.api.nvim_set_option_value("cursorline", false, { win = ui.main_window })
	vim.api.nvim_set_option_value("filetype", "dragonfly", { buf = ui.main_buffer })
	vim.api.nvim_set_option_value("winhighlight", "Normal:NormalFloat,NormalNC:NormalFloat", { win = ui.main_window })
	vim.keymap.set("n", "q", ui.close, { buffer = ui.main_buffer })
	vim.keymap.set("n", "<CR>", jump_to_match, { buffer = ui.main_buffer })
end

local function create_help_hint_window()
	ui.help_hint_buffer = vim.api.nvim_create_buf(false, true)
	ui.help_hint_window = vim.api.nvim_open_win(ui.help_hint_buffer, false, {
		relative = "win",
		row = vim.api.nvim_win_get_height(ui.main_window) - 1,
		col = 0,
		height = 1,
		width = 31,
		win = ui.main_window,
	})
	vim.api.nvim_set_option_value("winhighlight", "Normal:NormalFloat,NormalNC:NormalFloat",
		{ win = ui.help_hint_window })
	vim.api.nvim_buf_set_lines(ui.help_hint_buffer, 0, 1, true, { "  Press Ctrl + ? for help" })
	vim.api.nvim_buf_add_highlight(ui.help_hint_buffer, -1, "@comment", 0, 0, -1)
	vim.api.nvim_buf_add_highlight(ui.help_hint_buffer, -1, "@type", 0, #"  Press ", #"  Press Ctrl + ?")
end

local function create_replace_window()
	ui.replace_buffer = vim.api.nvim_create_buf(false, true)
	ui.replace_window = vim.api.nvim_open_win(ui.replace_buffer, false, {
		relative = "win",
		row = 7,
		col = 1,
		height = 1,
		width = 31,
		border = "rounded",
		win = ui.main_window,
	})
	vim.api.nvim_set_option_value("winhighlight", "Normal:NormalFloat,NormalNC:NormalFloat", { win = ui.replace_window })

	-- Add previous replace text
	if ui.replace_string then
		vim.api.nvim_buf_set_lines(ui.replace_buffer, 0, 1, true, { ui.replace_string })
	end

	-- Tab into matches
	vim.keymap.set("i", "<Tab>", function()
		vim.api.nvim_set_current_win(ui.main_window)
		vim.api.nvim_set_current_buf(ui.main_buffer)
		vim.api.nvim_win_set_cursor(ui.main_window, { 14, 0 })
		vim.api.nvim_set_option_value("cursorline", true, { win = ui.main_window })
		exit_insert_mode()
	end, { buffer = ui.replace_buffer })
	vim.keymap.set("i", "<CR>", function()
		vim.api.nvim_set_current_win(ui.main_window)
		vim.api.nvim_set_current_buf(ui.main_buffer)
		vim.api.nvim_win_set_cursor(ui.main_window, { 14, 0 })
		vim.api.nvim_set_option_value("cursorline", true, { win = ui.main_window })
		exit_insert_mode()
	end, { buffer = ui.replace_buffer })

	-- Unfocus buffer
	vim.keymap.set("i", "<Esc>", function()
		exit_insert_mode()
		vim.api.nvim_set_current_win(ui.previous_window)
	end, { buffer = ui.replace_buffer })

	-- Tab into search
	vim.keymap.set("i", "<S-Tab>", function()
		vim.api.nvim_set_current_win(ui.search_window)
		vim.api.nvim_set_current_buf(ui.search_buffer)
	end, { buffer = ui.replace_buffer })

	vim.api.nvim_create_autocmd("TextChangedI", {
		buffer = ui.replace_buffer,
		callback = function()
			ui.replace_string = table.concat(vim.api.nvim_buf_get_lines(ui.replace_buffer, 0, 1, true), "\n")
		end,
	})
end

local function create_search_window()
	ui.search_buffer = vim.api.nvim_create_buf(false, true)
	ui.search_window = vim.api.nvim_open_win(ui.search_buffer, true, {
		relative = "win",
		row = 2,
		col = 1,
		height = 1,
		width = 31,
		border = "rounded",
		win = ui.main_window
	})
	vim.api.nvim_set_option_value("winhighlight", "Normal:NormalFloat,NormalNC:NormalFloat", { win = ui.search_window })

	-- Options
	vim.api.nvim_set_option_value("number", false, { win = ui.search_window })
	vim.api.nvim_set_option_value("cursorline", false, { win = ui.search_window })

	-- Enter insert mode
	vim.api.nvim_command("startinsert")

	-- Add previous search text
	if ui.search_string then
		vim.api.nvim_buf_set_lines(ui.search_buffer, 0, 1, true, { ui.search_string })
		vim.api.nvim_win_set_cursor(ui.search_window, { 1, ui.search_string:len() })
	end

	-- Toggle case sensitive
	vim.keymap.set("i", "<C-c>", function()
		state.search_options.case_sensitive = not state.search_options.case_sensitive
		ui.perform_search()
	end, { buffer = ui.search_buffer })

	-- Toggle regex
	vim.keymap.set("i", "<C-r>", function()
		state.search_options.regex = not state.search_options.regex
		ui.perform_search()
	end, { buffer = ui.search_buffer })

	vim.keymap.set("i", "<C-?>", function()
		create_help_window()
		exit_insert_mode()
	end, { buffer = ui.search_buffer })

	-- Tab into replace box
	if state.replace then
		vim.keymap.set("i", "<Tab>", function()
			vim.api.nvim_set_current_win(ui.replace_window)
			vim.api.nvim_set_current_buf(ui.replace_buffer)
			vim.api.nvim_win_set_cursor(ui.replace_window,
				{ 1, #table.concat(vim.api.nvim_buf_get_lines(ui.replace_buffer, 0, 1, true), "\n") })
		end, { buffer = ui.search_buffer })
		vim.keymap.set("i", "<CR>", function()
			vim.api.nvim_set_current_win(ui.replace_window)
			vim.api.nvim_set_current_buf(ui.replace_buffer)
			vim.api.nvim_win_set_cursor(ui.replace_window,
				{ 1, #table.concat(vim.api.nvim_buf_get_lines(ui.replace_buffer, 0, 1, true), "\n") })
		end, { buffer = ui.search_buffer })
	end

	-- Unfocus buffer
	vim.keymap.set("i", "<Esc>", function()
		exit_insert_mode()
		vim.api.nvim_set_current_win(ui.previous_window)
	end, { buffer = ui.search_buffer })

	-- Close buffer
	vim.keymap.set("i", "<C-q>", function()
		ui.close()
	end, { buffer = ui.search_buffer })

	-- Ripgrep
	vim.api.nvim_create_autocmd("TextChangedI", {
		buffer = ui.search_buffer,
		callback = ui.perform_search
	})
end

local function create_search_options_window()
	ui.search_options_buffer = vim.api.nvim_create_buf(false, true)
	ui.search_options_window = vim.api.nvim_open_win(ui.search_options_buffer, false, {
		relative = "win",
		win = ui.search_window,
		row = 0,
		col = 31 - 6,
		width = 6,
		height = 1,
		style = "minimal",
		zindex = 999
	})
end

function ui.open_window()
	if not ui.previous_window then
		ui.previous_window = vim.fn.win_getid()
	end

	ui.close(true)
	config.options.on_open()

	create_main_window()
	create_search_window()

	if state.replace then
		create_replace_window()
	end

	create_search_options_window()
	create_help_hint_window()

	ui.redraw()
end

function ui.is_open()
	return vim.api.nvim_buf_is_valid(ui.main_buffer)
end

function ui.close(no_callback)
	local was_open = pcall(function()
		vim.api.nvim_buf_delete(ui.search_options_buffer, { force = true })
		vim.api.nvim_buf_delete(ui.search_buffer, { force = true })
		vim.api.nvim_buf_delete(ui.replace_buffer, { force = true })
		vim.api.nvim_buf_delete(ui.main_buffer, { force = true })
		vim.api.nvim_buf_delete(ui.help_hint_buffer, { force = true })
		pcall(function() vim.api.nvim_buf_delete(ui.help_buffer, { force = true }) end)
	end)

	if was_open and not no_callback then
		config.options.on_close()
		exit_insert_mode()
	end
end

return ui
