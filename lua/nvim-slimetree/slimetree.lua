local M = {}
local get_nodes = require("nvim-slimetree.get_nodes")
local utils = require("nvim-slimetree.utils")
-- Start goo move code
-- Utility function to check if a node is acceptable
local function is_acceptable_node(node, node_types)
	local acceptable_node_types = node_types.acceptable
	local node_type = node:type()
	local roots = utils.append(node_types.root, node_types.sub_roots)
	if acceptable_node_types[node_type] then
		-- Check if any ancestor is of type 'argument' or 'call', but stop at 'program'
		local parent = node:parent()
    -- don't look up the tree if you reach a node with a bad parent
		while parent and not utils.in_set(parent:type(), roots) do
      -- if parents imply node is part of a broader expression, return false
			if utils.in_set(parent:type(), node_types.bad_parents) then
				return false
			end
			parent = parent:parent()
		end
		return true -- Node is acceptable
	else
		return false -- Node type is not acceptable
	end
end

-- Utility function to check if a node type should be skipped
local function is_skip_node(node_type, node_types)
	return node_types.skip[node_type] or false
end

-- Function to traverse upwards and find the smallest acceptable node
local function find_smallest_acceptable_node(node, node_types)
	while node do
		if is_acceptable_node(node, node_types) then
			return node
		end
		node = node:parent()
	end
	return nil
end

-- Modified function to accept the tree as an argument and handle injections
local function get_node_under_cursor(bufnr, row, node_types)
	-- If 'bufnr' is not provided, use the current buffer
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- If 'row' is not provided, get it from the current cursor position
	if not row then
		local cursor = vim.api.nvim_win_get_cursor(0) -- {line, col}, 1-based indexing
		row = cursor[1] - 1 -- Convert to 0-based indexing
	end

	-- Ensure 'row' is a valid number
	if type(row) ~= "number" then
		vim.notify("Invalid row number provided.", vim.log.levels.ERROR)
		return nil
	end

	local row_nodes = {}

	-- Get row content
	local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)
	local line = lines[1] or ""
	if line == "" then
		-- vim.notify("The specified row is empty.", vim.log.levels.INFO)
		return nil
	end

	-- Get the column position of the first non-whitespace character
	local start_col = (line:find("%S") or 1) - 1 -- 0-based indexing

	local col = start_col
	local line_length = #line

	-- While not at the end of the line
	while col < line_length do
		-- Retrieve node at current position, handling injections
		local node = vim.treesitter.get_node({
			bufnr = bufnr,
			pos = { row, col },
			ignore_injections = false,
		})
		if node then
			-- Get the start and end columns of the node
			local _, start_col_node, _, end_col_node = node:range()

			-- Ensure the node starts on the specified row and at the current column
			if start_col_node == col then
				table.insert(row_nodes, node)

				-- Move to the end column of the current node
				local prev_col = col
				col = end_col_node

				-- Ensure col advances to prevent infinite loops
				if col <= prev_col then
					col = prev_col + 1
				end

				-- If whitespace, get position of the next non-whitespace character
				while col < line_length and line:sub(col + 1, col + 1):match("%s") do
					col = col + 1
				end
			else
				-- If the node does not start at the current column, increment col
				col = col + 1
			end
		else
			-- If no node is found, move to the next character
			col = col + 1
		end
	end

	-- Determine the node with the widest column span
	local widest_node = nil
	local max_span = -1

	for _, n in ipairs(row_nodes) do
		local _, start_col_node, _, end_col_node = n:range()
		local span = end_col_node - start_col_node
		local node_type = n:type()
		if is_skip_node(node_type, node_types) then
			span = 0
		end
		if span > max_span then
			max_span = span
			widest_node = n
		end
	end

	if widest_node then
		local current_node = widest_node
		local parent = current_node:parent()
		while parent and parent:type() ~= "program" and parent:type() ~= "chunk" do
			local parent_start_row, _, _, _ = parent:range()
			if parent_start_row == row then
				current_node = parent
				parent = current_node:parent()
			else
				break
			end
		end
		return current_node
	end
	-- Return the widest node if no suitable parent is found
	return widest_node
end

-- Helper function to get the next node in source order
local function get_next_node_in_source_order(node)
	if not node then
		return nil
	end

	-- If the node has children, go to the first child
	if node:child_count() > 0 then
		return node:child(0)
	end

	-- Else, traverse upwards to find the next sibling
	while node do
		local next_sibling = node:next_sibling()
		if next_sibling then
			return next_sibling
		end
		node = node:parent()
	end

	-- Reached the end of the tree
	return nil
end

-- Optimized function to find the next acceptable node
local function find_next_acceptable_node(bufnr, current_row, current_col, node_types)
	-- Get the node at the current position
	local node = vim.treesitter.get_node({
		bufnr = bufnr,
		pos = { current_row, current_col },
		ignore_injections = false,
	})

	if not node then
		return nil
	end

	-- Move to the next node in source order
	node = get_next_node_in_source_order(node)

	while node do
		-- Get the starting position of the node
		local start_row, start_col = node:range()

		-- Ensure the node is after the current cursor position
		if (start_row > current_row) or (start_row == current_row and start_col > current_col) then
			-- Check if the node is acceptable
			if is_acceptable_node(node, node_types) then
				return node
			end
		end

		-- Move to the next node in source order
		node = get_next_node_in_source_order(node)
	end

	-- No acceptable node found
	return nil
end

-- Function to send a range of lines to vim-slime
local function send_to_slime(bufnr, start_line, end_line)
	-- vim-slime expects 1-based line numbers
	local range = string.format("%d,%dSlimeSend", start_line + 1, end_line + 1)
	vim.cmd(range)
end

function M.SlimeCurrentLine()
	local bufnr = vim.api.nvim_get_current_buf()
	local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1 -- Get current line (0-based)
	send_to_slime(bufnr, current_line, current_line)
end

-- Main function to perform the chunking and sending
function M.goo_move(hold_position)
	if _G.goo_started == false and _G.use_goo == true then
		vim.notify("Please start goo first", vim.log.levels.ERROR)
		return
	end
	hold_position = hold_position or false
	-- Get the current buffer and cursor position
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0) -- {row, col}
	local row = cursor[1] - 1 -- Convert to 0-based
	local col = cursor[2]
	local last_line = vim.api.nvim_buf_line_count(bufnr) - 1

	-- get nodes for bufnr
	local node_types = get_nodes.get_nodes()

	while row < last_line do
		local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
		local is_empty = line:match("^%s*$") ~= nil

		-- Get treesitter node at current position, handling injections
		local node = get_node_under_cursor(bufnr, row, node_types)
		local node_type = node and node:type() or nil
		local should_skip = is_empty or (node_type and node_types.skip[node_type])

		if not should_skip then
			vim.api.nvim_win_set_cursor(0, { row + 1, cursor[2] })
			break
		end
		row = row + 1
	end

	-- Retrieve the current line's content
	local current_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]

	-- Check if the current line is entirely empty
	local is_line_empty = current_line:match("^%s*$") ~= nil

	local node = get_node_under_cursor(bufnr, row, node_types)
	if not node then
		-- vim.notify("No Tree-sitter node found under the cursor.", vim.log.levels.WARN)
		return
	end

	-- Check if the current node is a skip node (e.g., comment)
	local node_type = node:type()
	local is_skip = is_skip_node(node_type, node_types)

	if is_line_empty or is_skip then
		-- If the line is empty or a skip node, search for the next acceptable node below
		local acceptable_node = find_next_acceptable_node(bufnr, row, col, node_types)
		if not acceptable_node then
			-- vim.notify("No acceptable chunk found after the cursor.", vim.log.levels.INFO)
			return
		end

		-- Get the range of the acceptable node
		local start_row, _, end_row, _ = acceptable_node:range()

		-- Send the lines to vim-slime
		send_to_slime(bufnr, start_row, end_row)

		-- Move the cursor to the line below the end of the range
		local total_lines = vim.api.nvim_buf_line_count(bufnr)
		local new_cursor_row = end_row + 1
		if new_cursor_row < total_lines then
			vim.api.nvim_win_set_cursor(0, { new_cursor_row + 1, 0 }) -- Convert back to 1-based
		else
			vim.api.nvim_win_set_cursor(0, { total_lines, 0 }) -- Move to the last line if exceeded
		end

		return
	else
		-- If the line has code (possibly preceded by whitespace), move cursor to first non-whitespace character
		local first_non_ws = current_line:find("%S")
		if first_non_ws and first_non_ws > 1 then
			vim.api.nvim_win_set_cursor(0, { row + 1, first_non_ws - 1 }) -- Move cursor to first non-whitespace
			col = first_non_ws - 1 -- Update column position

			-- Update the node after moving the cursor
			node = get_node_under_cursor(bufnr, row, node_types)
			if not node then
				-- vim.notify("No Tree-sitter node found after moving cursor.", vim.log.levels.WARN)
				return
			end

			node_type = node:type()
			is_skip = is_skip_node(node_type, node_types)
			if is_skip then
				-- If the new node is a skip node, treat it like an empty line
				local acceptable_node = find_next_acceptable_node(bufnr, row, col, node_types)
				if not acceptable_node then
					-- vim.notify("No acceptable chunk found after the cursor.", vim.log.levels.INFO)
					return
				end

				-- Get the range of the acceptable node
				local start_row, _, end_row, _ = acceptable_node:range()

				-- Send the lines to vim-slime
				send_to_slime(bufnr, start_row, end_row)

				-- Move the cursor to the line below the end of the range
				local total_lines = vim.api.nvim_buf_line_count(bufnr)
				local new_cursor_row = end_row + 1
				if new_cursor_row < total_lines then
					vim.api.nvim_win_set_cursor(0, { new_cursor_row + 1, 0 }) -- Convert back to 1-based
				else
					vim.api.nvim_win_set_cursor(0, { total_lines, 0 }) -- Move to the last line if exceeded
				end

				return
			end
		end
	end

	-- At this point, the line is not empty and not a skip node
	-- Find the smallest acceptable node starting from the current node
	local acceptable_node = find_smallest_acceptable_node(node, node_types)

	if acceptable_node then
		-- Ensure that if the node starts after the cursor's column on the same line, we still consider it
		local start_row, start_col, end_row, end_col = acceptable_node:range()
		if start_row == row and start_col > col then
			-- The acceptable node starts after the cursor's column, so treat it as the next acceptable node
			acceptable_node = find_next_acceptable_node(bufnr, row, col, node_types)
			if not acceptable_node then
				-- vim.notify("No acceptable chunk found after the cursor.", vim.log.levels.INFO)
				return
			end
		end
	else
		-- If current node isn't acceptable, search for the next acceptable node below
		acceptable_node = find_next_acceptable_node(bufnr, row, col, node_types)
		-- vim.notify("Found node type: " .. node_type)
		if not acceptable_node then
			-- vim.notify("No acceptable chunk found.", vim.log.levels.INFO)
			return
		end
	end

	-- Get the range of the acceptable node
	local start_row, _, end_row, _ = acceptable_node:range()

	-- Send the lines to vim-slime
	send_to_slime(bufnr, start_row, end_row)

	if hold_position == true then
		return
	end

	-- Move the cursor to the line below the end of the range
	local total_lines = vim.api.nvim_buf_line_count(bufnr)
	local new_cursor_row = end_row + 1
	if new_cursor_row < total_lines then
		vim.api.nvim_win_set_cursor(0, { new_cursor_row + 1, 0 }) -- Convert back to 1-based
	else
		vim.api.nvim_win_set_cursor(0, { total_lines, 0 }) -- Move to the last line if exceeded
	end
end

-- END goo move code
-- Helper function to execute a shell command and return its output

function M.goo_send(text)
	vim.fn["slime#send"](text .. "\n")
end

return M
