local api = {}

---DragonflyActive integer[]
api.drawn_buffers = {}

---@alias LinePart { [1]?: string, text?: string, highlight?: string }

--- Appends a line of text to the given buffer.
---
--- @param buffer integer The buffer to write to.
---
--- @param parts nil | string | LinePart | LinePart[] The text to write to the buffer. This can be either:
--- - `nil`: To write a blank line
--- - `string`: To write the string
--- - `{ [1]?: string, text?: string, highlight?: string }`: To write the string given by `[1]` (or `text` if
---   `[1]` is `nil`) colored with the highlight group `highlight` if it's present.
--- - `{ [1]?: string, text?: string, highlight?: string }[]`: The same as above, but can write multiple differently
---   highlighted text segments onto the same line.
---
--- @param options nil | { center_in?: integer } Additional drawing options. Valid values are:
--- - `center_in: integer`: To center the text in a window (pass the window ID here)
---
---@return nil
function vim.api.nvim_buf_append_line(buffer, parts, options)
	options = options or {}

	if parts == nil then parts = "" end
	if type(parts) == "string" then
		parts = { { parts } }
	end

	if parts.highlight then
		parts = { parts }
	end

	-- Text
	local text = ""
	for _, part in ipairs(parts) do
		text = text .. (part[1] or part.text)
	end

	-- Alignment
	local shift = 0
	if options.center_in then
		shift = math.floor(vim.api.nvim_win_get_width(options.center_in) / 2) -
			math.floor(vim.fn.strdisplaywidth(text) / 2)
		text = (" "):rep(shift) .. text
	end

	-- Line number
	local line = vim.api.nvim_buf_line_count(buffer)
	if not vim.list_contains(api.drawn_buffers, buffer) then
		line = 0
	end

	-- Column number
	local start = -1
	if not vim.list_contains(api.drawn_buffers, buffer) then
		start = 0
		table.insert(api.drawn_buffers, buffer)
	end

	-- Write the line
	vim.api.nvim_buf_set_lines(buffer, start, -1, false, { text })

	-- Highlighting (colors, italics, bold, etc.)
	text = ""
	for _, part in ipairs(parts) do
		text = text .. (part[1] or part.text)
		if part.highlight then
			local highlight_group = assert(part.highlight)

			-- Add the highlight
			vim.api.nvim_buf_add_highlight(
				buffer,                      -- Buffer
				-1,                          -- Namespace ID
				highlight_group,             -- Highlight group
				line,                        -- Line
				#text - #(part[1] or part.text) + shift, -- Start column
				#text + shift                -- End column
			)
		end
	end
end

return api
