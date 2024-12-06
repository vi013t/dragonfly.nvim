local ui = {}

local config = require("dragonfly.config")

ui.matches = {}

local is_first_draw_call = true

local function write_line(option_list, is_centered)
	if type(option_list) == "string" then
		option_list = { { text = option_list } }
	end

	-- Text
	local text = ""
	for _, options in ipairs(option_list) do
		text = text .. options.text
	end

	-- Alignment
	local shift = 0
	if is_centered then
		shift = math.floor(ui.width / 2) - math.floor(vim.fn.strdisplaywidth(text) / 2)
		text = (" "):rep(shift) .. text
	end

	-- Line number
	local line = vim.api.nvim_buf_line_count(ui.buffer)
	if is_first_draw_call then
		line = 0
	end

	-- Column number
	local start = -1
	if is_first_draw_call then
		start = 0
	end
	is_first_draw_call = false

	-- Write the line
	vim.api.nvim_buf_set_lines(ui.buffer, start, -1, false, { text })

	-- Highlighting (colors, italics, bold, etc.)
	text = ""
	for _, options in ipairs(option_list) do
		text = text .. options.text
		if options.foreground or options.background then
			local highlight_group = options.foreground or options.background

			-- Add the highlight
			vim.api.nvim_buf_add_highlight(
				ui.buffer,         -- Buffer
				-1,                -- Namespace ID
				highlight_group,   -- Highlight group
				line,              -- Line
				#text - #options.text + shift, -- Start column
				#text + shift      -- End column
			)
		end
	end
end

---@param paths SegmentedMatch[]
---
---@return MatchDirectory
local function group_paths(paths, iteration)
	iteration = iteration or 1
	local folder_entries = {}
	for _, match in ipairs(paths) do
		if #match.segments == 0 then
			table.insert(folder_entries, { line = match.line, column = match.column })
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

---@alias Match { file_name: string, line: number, column: number }

---@alias SegmentedMatch { segments: string[], line: number, column: number }
---@alias MatchDirectory table<string, (Match | MatchDirectory)[]>

---@param results string[]
---
---@return MatchDirectory
local function group_results(results)
	---@type Match[]
	local matches = {}
	for _, result in ipairs(results) do
		local file_name, line, column = result:match("^([^:]+):(%d+):(%d+)")
		table.insert(matches,
			{ file_name = assert(file_name), line = tonumber(assert(line)), column = tonumber(assert(column)) })
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
			column = match.column
		})
	end

	return group_paths(paths)
end

local function draw_folders(folders, indent, last_stack)
	indent = indent or 0
	last_stack = last_stack or {}

	local indentation = ("│ "):rep(indent - 1)
	if indent == 0 or indent == 1 then indentation = "" end
	indentation = "  " .. indentation

	-- File matches
	for index, position in ipairs(folders) do
		local bar = "│"
		if index == #folders then bar = "└" end

		write_line({
			{ text = indentation, foreground = "@comment" },
			{ text = bar, foreground = "@comment", },
			{ text = "  On line ", foreground = "@comment" },
			{ text = tostring(position.line), foreground = "@type" },
			{ text = ", column ", foreground = "@comment" },
			{ text = tostring(position.column), foreground = "@type" },
		})
	end

	local paircount = 0

	for name, _ in pairs(folders) do
		if type(name) ~= "number" then
			paircount = paircount + 1
		end
	end

	-- Folders
	local index = 1
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
			{ text = indentation, foreground = "@comment" }
		}

		if indent ~= 0 then
			table.insert(line, { text = "│ ", foreground = "@comment" })
		end

		table.insert(line, { text = icon, foreground = icon_color })
		table.insert(line, { text = " " .. name })

		write_line(line)

		table.insert(last_stack, paircount == index)
		draw_folders(contents, indent + 1, last_stack)

		paircount = paircount + 1

		::continue::
	end
end

function ui.update()
	is_first_draw_call = true

	write_line("")
	write_line({ { text = "  Search ", foreground = "@type" } })
	write_line("")
	write_line("")
	write_line("")
	write_line("")
	write_line({ { text = "  Replace 󰛔", foreground = "@type" } })
	write_line("")
	write_line("")
	write_line("")
	write_line("")
	write_line({ { text = "  Matches 󱨉", foreground = "@type" } })
	write_line("")

	local matches = group_results(ui.matches)
	draw_folders(matches)
end

local function go_to(line)
	local line_number, column_number = line:match("On line (%d+), column (%d+)")
end

function ui.open_window()
	ui.close(true)
	config.options.on_open()

	ui.buffer = vim.api.nvim_create_buf(false, true)
	ui.window = vim.api.nvim_open_win(ui.buffer, true, {
		width = 35,
		style = "minimal",
		split = "left",
	})
	vim.api.nvim_set_option_value("number", false, { win = ui.window })
	vim.api.nvim_set_option_value("cursorline", false, { win = ui.window })
	vim.api.nvim_set_option_value("filetype", "dragonfly", { buf = ui.buffer })
	vim.api.nvim_set_option_value("winhighlight", "Normal:NormalFloat,NormalNC:NormalFloat", { win = ui.window })
	vim.keymap.set("n", "q", ui.close, { buffer = ui.buffer })

	-- Replace buffer
	ui.replace_buffer = vim.api.nvim_create_buf(false, true)
	ui.replace_window = vim.api.nvim_open_win(ui.replace_buffer, true, {
		relative = "win",
		row = 7,
		col = 1,
		height = 1,
		width = 31,
		border = "rounded",
		win = ui.window,
	})

	-- Tab into matches
	vim.keymap.set("i", "<Tab>", function()
		vim.api.nvim_set_current_win(ui.window)
		vim.api.nvim_set_current_buf(ui.buffer)
		vim.api.nvim_win_set_cursor(ui.window, { 14, 0 })
		vim.api.nvim_set_option_value("cursorline", true, { win = ui.window })
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'i', true)
	end, { buffer = ui.replace_buffer })

	-- Search buffer
	ui.search_buffer = vim.api.nvim_create_buf(false, true)
	ui.search_window = vim.api.nvim_open_win(ui.search_buffer, true, {
		relative = "win",
		row = 2,
		col = 1,
		height = 1,
		width = 31,
		border = "rounded",
		win = ui.window
	})
	vim.api.nvim_set_option_value("number", false, { win = ui.search_window })
	vim.api.nvim_set_option_value("cursorline", false, { win = ui.search_window })
	vim.api.nvim_command("startinsert")
	if ui.search_string then
		vim.api.nvim_buf_set_lines(ui.search_buffer, 0, 1, true, { ui.search_string })
		vim.api.nvim_win_set_cursor(ui.search_window, { 1, ui.search_string:len() })
	end

	-- Tab into replace box
	vim.keymap.set("i", "<Tab>", function()
		vim.api.nvim_set_current_win(ui.replace_window)
		vim.api.nvim_set_current_buf(ui.replace_buffer)
	end, { buffer = ui.search_buffer })

	-- Close buffer
	vim.keymap.set("i", "<Esc>", function()
		ui.close()
	end, { buffer = ui.search_buffer })

	-- Ripgrep
	vim.api.nvim_create_autocmd("TextChangedI", {
		buffer = ui.search_buffer,
		callback = function()
			ui.matches = {}
			ui.search_string = table.concat(vim.api.nvim_buf_get_lines(ui.search_buffer, 0, 1, true), "\n")
			if ui.search_string:match("^%s*$") then return end
			local output = assert(vim.system(
				{ "rg", "--no-heading", "--vimgrep", "--color=never", "--only-matching", ui.search_string },
				{ text = true }):wait().stdout)
			for line in output:gmatch("[^\r\n]+") do
				table.insert(ui.matches, line)
			end
			ui.update()
		end
	})

	ui.update()
end

function ui.close(no_callback)
	local was_open = pcall(function()
		vim.api.nvim_buf_delete(ui.search_buffer, { force = true })
		vim.api.nvim_buf_delete(ui.replace_buffer, { force = true })
		vim.api.nvim_buf_delete(ui.buffer, { force = true })
	end)
	if was_open and not no_callback then
		config.options.on_close()
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'i', true)
	end
end

return ui
