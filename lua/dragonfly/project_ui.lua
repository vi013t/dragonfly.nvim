local project_ui = {}

local config = require("dragonfly.config")
local state = require("dragonfly.state")
local api = require("dragonfly.api")
local utils = require("dragonfly.utils")

project_ui.matches = {}

---@type (Match | boolean)[]
project_ui.match_lines = {}

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

		vim.api.nvim_buf_append_line(project_ui.main_buffer, line)
		table.insert(project_ui.match_lines, false)

		draw_folders(contents, indent + 1)

		paircount = paircount + 1

		::continue::
	end

	-- File matches
	for index, match in ipairs(folders) do
		---@cast match Match
		local bar = "│ "
		if index == #folders then bar = "└ " end

		vim.api.nvim_buf_append_line(project_ui.main_buffer, {
			{ indentation .. bar .. tostring(match.line) .. ":" .. tostring(match.column) .. ": ", highlight = "@comment" },
			{ match.match,                                                                         highlight = "@type" },
		})
		table.insert(project_ui.match_lines, match)
	end
end

function project_ui.perform_search()
	project_ui.matches = {}
	project_ui.match_lines = {}
	project_ui.search_string = table.concat(vim.api.nvim_buf_get_lines(project_ui.search_buffer, 0, 1, true), "\n")
	if project_ui.search_string:match("^%s*$") then
		project_ui.redraw()
		return
	end

	-- Generate ripgrep command
	local ripgrep_command = { "rg", "--no-heading", "--vimgrep", "--color=never", "--only-matching", }
	if not state.search_options.regex then table.insert(ripgrep_command, "--fixed-strings") end
	if not state.search_options.case_sensitive then table.insert(ripgrep_command, "--ignore-case") end
	table.insert(ripgrep_command, project_ui.search_string)

	local output = assert(vim.system(ripgrep_command, { true }):wait().stdout)
	for line in output:gmatch("[^\r\n]+") do
		table.insert(project_ui.matches, line)
	end
	project_ui.redraw()
end

function project_ui.redraw()
	api.drawn_buffers = {}

	vim.api.nvim_buf_append_line(project_ui.main_buffer)
	vim.api.nvim_buf_append_line(project_ui.main_buffer, { "  Search ", highlight = "@type" })
	vim.api.nvim_buf_append_line(project_ui.main_buffer)
	vim.api.nvim_buf_append_line(project_ui.main_buffer)
	vim.api.nvim_buf_append_line(project_ui.main_buffer)
	vim.api.nvim_buf_append_line(project_ui.main_buffer)

	if state.replace then
		vim.api.nvim_buf_append_line(project_ui.main_buffer, { "  Replace 󰛔", highlight = "@type" })
		vim.api.nvim_buf_append_line(project_ui.main_buffer)
		vim.api.nvim_buf_append_line(project_ui.main_buffer)
		vim.api.nvim_buf_append_line(project_ui.main_buffer)
		vim.api.nvim_buf_append_line(project_ui.main_buffer)
	end

	vim.api.nvim_buf_append_line(project_ui.main_buffer, { "  Matches 󱨉", highlight = "@type" })
	vim.api.nvim_buf_append_line(project_ui.main_buffer)

	local matches = group_results(project_ui.matches)
	draw_folders(matches)

	vim.api.nvim_buf_append_line(project_ui.main_buffer)
	vim.api.nvim_buf_append_line(project_ui.main_buffer)

	vim.api.nvim_buf_set_lines(project_ui.search_options_buffer, 0, 1, true, { "Aa .* " })

	local case_sensitive_highlight = "@comment"
	if state.search_options.case_sensitive then case_sensitive_highlight = "@type" end
	vim.api.nvim_buf_add_highlight(project_ui.search_options_buffer, -1, case_sensitive_highlight, 0, 0, 2)

	local regex_highlight = "@comment"
	if state.search_options.regex then regex_highlight = "@type" end
	vim.api.nvim_buf_add_highlight(project_ui.search_options_buffer, -1, regex_highlight, 0, 3, -1)
end

local function jump_to_match()
	local line = vim.api.nvim_win_get_cursor(project_ui.main_window)[1]
	local blank_lines = 8
	if state.replace then blank_lines = blank_lines + 5 end
	local match = project_ui.match_lines[line - blank_lines]
	if not match then return end
	vim.api.nvim_set_current_win(state.previous_window)
	vim.cmd(":e " .. match.file_name)
	vim.fn.cursor({ match.line, match.column })
end

local function create_help_window()
	project_ui.help_buffer = vim.api.nvim_create_buf(false, true)
	project_ui.help_window = vim.api.nvim_open_win(project_ui.help_buffer, true, {
		relative = "win",
		win = project_ui.search_window,
		row = 10,
		col = -1,
		width = 31,
		height = 13,
		style = "minimal",
		zindex = 9999,
		border = "rounded",
	})

	vim.keymap.set("n", "q", function()
		vim.api.nvim_buf_delete(project_ui.help_buffer, { force = true })
		vim.api.nvim_set_current_win(project_ui.search_window)
		vim.api.nvim_set_current_buf(project_ui.search_buffer)
		vim.api.nvim_command("startinsert")
	end, { buffer = project_ui.help_buffer })

	vim.api.nvim_buf_append_line(project_ui.help_buffer, { "Dragonfly Help", highlight = "@type" },
		{ center_in = project_ui.help_window })
	vim.api.nvim_buf_append_line(project_ui.help_buffer)
	vim.api.nvim_buf_append_line(project_ui.help_buffer,
		{ { " <C-c>", highlight = "@type" }, { ": Toggle Case Sensitivity" } })
	vim.api.nvim_buf_append_line(project_ui.help_buffer,
		{ { " <C-r>", highlight = "@type" }, { ": Toggle Regex Searching" } })
	vim.api.nvim_buf_append_line(project_ui.help_buffer, { { " <Tab>", highlight = "@type" }, { ": Next text box" } })
	vim.api.nvim_buf_append_line(project_ui.help_buffer,
		{ { " <S-Tab>", highlight = "@type" }, { ": Previous text box" } })
	vim.api.nvim_buf_append_line(project_ui.help_buffer, { { " <Enter>", highlight = "@type" }, { ": Jump to match" } })
	vim.api.nvim_buf_append_line(project_ui.help_buffer, { { " <Esc>", highlight = "@type" }, { ": Unfocus Dragonfly" } })
	vim.api.nvim_buf_append_line(project_ui.help_buffer, { { " q", highlight = "@type" }, { ": Close Dragonfly" } })
	vim.api.nvim_buf_append_line(project_ui.help_buffer)
	vim.api.nvim_buf_append_line(project_ui.help_buffer)
	vim.api.nvim_buf_append_line(project_ui.help_buffer, { " Press q to close this window", highlight = "@comment" })
end

local function create_main_window()
	project_ui.main_buffer = vim.api.nvim_create_buf(false, true)
	project_ui.main_window = vim.api.nvim_open_win(project_ui.main_buffer, false, {
		width = 35,
		style = "minimal",
		split = "left",
	})
	vim.api.nvim_set_option_value("number", false, { win = project_ui.main_window })
	vim.api.nvim_set_option_value("cursorline", false, { win = project_ui.main_window })
	vim.api.nvim_set_option_value("filetype", "dragonfly", { buf = project_ui.main_buffer })
	vim.api.nvim_set_option_value("winhighlight", "Normal:NormalFloat,NormalNC:NormalFloat",
		{ win = project_ui.main_window })
	vim.keymap.set("n", "q", project_ui.close, { buffer = project_ui.main_buffer })
	vim.keymap.set("n", "<CR>", jump_to_match, { buffer = project_ui.main_buffer })
end

local function create_help_hint_window()
	project_ui.help_hint_buffer = vim.api.nvim_create_buf(false, true)
	project_ui.help_hint_window = vim.api.nvim_open_win(project_ui.help_hint_buffer, false, {
		relative = "win",
		row = vim.api.nvim_win_get_height(project_ui.main_window) - 1,
		col = 0,
		height = 1,
		width = 31,
		win = project_ui.main_window,
	})
	vim.api.nvim_set_option_value("winhighlight", "Normal:NormalFloat,NormalNC:NormalFloat",
		{ win = project_ui.help_hint_window })
	vim.api.nvim_buf_set_lines(project_ui.help_hint_buffer, 0, 1, true, { "  Press Ctrl + ? for help" })
	vim.api.nvim_buf_add_highlight(project_ui.help_hint_buffer, -1, "@comment", 0, 0, -1)
	vim.api.nvim_buf_add_highlight(project_ui.help_hint_buffer, -1, "@type", 0, #"  Press ", #"  Press Ctrl + ?")
end

local function create_replace_window()
	project_ui.replace_buffer = vim.api.nvim_create_buf(false, true)
	project_ui.replace_window = vim.api.nvim_open_win(project_ui.replace_buffer, false, {
		relative = "win",
		row = 7,
		col = 1,
		height = 1,
		width = 31,
		border = "rounded",
		win = project_ui.main_window,
	})
	vim.api.nvim_set_option_value("winhighlight", "Normal:NormalFloat,NormalNC:NormalFloat",
		{ win = project_ui.replace_window })

	-- Add previous replace text
	if project_ui.replace_string then
		vim.api.nvim_buf_set_lines(project_ui.replace_buffer, 0, 1, true, { project_ui.replace_string })
	end

	-- Tab into matches
	vim.keymap.set("i", "<Tab>", function()
		vim.api.nvim_set_current_win(project_ui.main_window)
		vim.api.nvim_set_current_buf(project_ui.main_buffer)
		vim.api.nvim_win_set_cursor(project_ui.main_window, { 14, 0 })
		vim.api.nvim_set_option_value("cursorline", true, { win = project_ui.main_window })
		utils.exit_insert_mode()
	end, { buffer = project_ui.replace_buffer })
	vim.keymap.set("i", "<CR>", function()
		vim.api.nvim_set_current_win(project_ui.main_window)
		vim.api.nvim_set_current_buf(project_ui.main_buffer)
		vim.api.nvim_win_set_cursor(project_ui.main_window, { 14, 0 })
		vim.api.nvim_set_option_value("cursorline", true, { win = project_ui.main_window })
		utils.exit_insert_mode()
	end, { buffer = project_ui.replace_buffer })

	-- Unfocus buffer
	vim.keymap.set("i", "<Esc>", function()
		utils.exit_insert_mode()
		vim.api.nvim_set_current_win(state.previous_window)
	end, { buffer = project_ui.replace_buffer })

	-- Tab into search
	vim.keymap.set("i", "<S-Tab>", function()
		vim.api.nvim_set_current_win(project_ui.search_window)
		vim.api.nvim_set_current_buf(project_ui.search_buffer)
	end, { buffer = project_ui.replace_buffer })

	vim.api.nvim_create_autocmd("TextChangedI", {
		buffer = project_ui.replace_buffer,
		callback = function()
			project_ui.replace_string = table.concat(vim.api.nvim_buf_get_lines(project_ui.replace_buffer, 0, 1, true),
				"\n")
		end,
	})
end

local function create_search_window()
	project_ui.search_buffer = vim.api.nvim_create_buf(false, true)
	project_ui.search_window = vim.api.nvim_open_win(project_ui.search_buffer, true, {
		relative = "win",
		row = 2,
		col = 1,
		height = 1,
		width = 31,
		border = "rounded",
		win = project_ui.main_window
	})
	vim.api.nvim_set_option_value("winhighlight", "Normal:NormalFloat,NormalNC:NormalFloat",
		{ win = project_ui.search_window })

	-- Options
	vim.api.nvim_set_option_value("number", false, { win = project_ui.search_window })
	vim.api.nvim_set_option_value("cursorline", false, { win = project_ui.search_window })

	-- Enter insert mode
	vim.api.nvim_command("startinsert")

	-- Add previous search text
	if project_ui.search_string then
		vim.api.nvim_buf_set_lines(project_ui.search_buffer, 0, 1, true, { project_ui.search_string })
		vim.api.nvim_win_set_cursor(project_ui.search_window, { 1, project_ui.search_string:len() })
	end

	-- Toggle case sensitive
	vim.keymap.set("i", "<C-c>", function()
		state.search_options.case_sensitive = not state.search_options.case_sensitive
		project_ui.perform_search()
	end, { buffer = project_ui.search_buffer })

	-- Toggle regex
	vim.keymap.set("i", "<C-r>", function()
		state.search_options.regex = not state.search_options.regex
		project_ui.perform_search()
	end, { buffer = project_ui.search_buffer })

	-- Help window
	vim.keymap.set("i", "<C-?>", function()
		create_help_window()
		utils.exit_insert_mode()
	end, { buffer = project_ui.search_buffer })

	-- Tab into replace box
	if state.replace then
		vim.keymap.set("i", "<Tab>", function()
			vim.api.nvim_set_current_win(project_ui.replace_window)
			vim.api.nvim_set_current_buf(project_ui.replace_buffer)
			vim.api.nvim_win_set_cursor(project_ui.replace_window,
				{ 1, #table.concat(vim.api.nvim_buf_get_lines(project_ui.replace_buffer, 0, 1, true), "\n") })
		end, { buffer = project_ui.search_buffer })
		vim.keymap.set("i", "<CR>", function()
			vim.api.nvim_set_current_win(project_ui.replace_window)
			vim.api.nvim_set_current_buf(project_ui.replace_buffer)
			vim.api.nvim_win_set_cursor(project_ui.replace_window,
				{ 1, #table.concat(vim.api.nvim_buf_get_lines(project_ui.replace_buffer, 0, 1, true), "\n") })
		end, { buffer = project_ui.search_buffer })
	else
		vim.keymap.set("i", "<Tab>", function()
			vim.api.nvim_set_current_win(project_ui.main_window)
			vim.api.nvim_set_current_buf(project_ui.main_buffer)
			vim.api.nvim_win_set_cursor(project_ui.main_window, { 9, 0 })
			vim.api.nvim_set_option_value("cursorline", true, { win = project_ui.main_window })
			utils.exit_insert_mode()
		end)
		vim.keymap.set("i", "<CR>", function()
			vim.api.nvim_set_current_win(project_ui.main_window)
			vim.api.nvim_set_current_buf(project_ui.main_buffer)
			vim.api.nvim_win_set_cursor(project_ui.main_window, { 9, 0 })
			vim.api.nvim_set_option_value("cursorline", true, { win = project_ui.main_window })
			utils.exit_insert_mode()
		end)
	end

	-- Unfocus buffer
	vim.keymap.set("i", "<Esc>", function()
		utils.exit_insert_mode()
		vim.api.nvim_set_current_win(state.previous_window)
	end, { buffer = project_ui.search_buffer })

	-- Close buffer
	vim.keymap.set("i", "<C-q>", function()
		project_ui.close()
	end, { buffer = project_ui.search_buffer })

	-- Ripgrep
	vim.api.nvim_create_autocmd("TextChangedI", {
		buffer = project_ui.search_buffer,
		callback = project_ui.perform_search
	})
end

local function create_search_options_window()
	project_ui.search_options_buffer = vim.api.nvim_create_buf(false, true)
	project_ui.search_options_window = vim.api.nvim_open_win(project_ui.search_options_buffer, false, {
		relative = "win",
		win = project_ui.search_window,
		row = 0,
		col = 31 - 6,
		width = 6,
		height = 1,
		style = "minimal",
		zindex = 999
	})
end

function project_ui.open_window()
	if not state.previous_window then
		state.previous_window = vim.fn.win_getid()
	end

	project_ui.close(true)
	config.options.on_open()

	create_main_window()
	create_search_window()

	if state.replace then
		create_replace_window()
	end

	create_search_options_window()
	create_help_hint_window()

	project_ui.redraw()
end

function project_ui.is_open()
	return project_ui.main_buffer and vim.api.nvim_buf_is_valid(project_ui.main_buffer)
end

function project_ui.close(no_callback)
	local was_open = pcall(function()
		vim.api.nvim_buf_delete(project_ui.search_options_buffer, { force = true })
		vim.api.nvim_buf_delete(project_ui.search_buffer, { force = true })
		vim.api.nvim_buf_delete(project_ui.replace_buffer, { force = true })
		vim.api.nvim_buf_delete(project_ui.main_buffer, { force = true })
		vim.api.nvim_buf_delete(project_ui.help_hint_buffer, { force = true })
		pcall(function() vim.api.nvim_buf_delete(project_ui.help_buffer, { force = true }) end)
	end)

	if was_open and not no_callback then
		config.options.on_close()
		utils.exit_insert_mode()
	end
end

return project_ui