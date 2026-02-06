local M = {}
-- logical test of whether x is container in y
function M.in_set(x, y)
	if type(y) ~= "table" then
    print(y)
		error("Expected a table as the second argument, got " .. type(y))
	end
	-- If treating y as a set:
	return y[x] == true
end

function M.append(x, y)
    local result = {}

    -- Add all entries from x to result
    for k, v in pairs(x) do
        if v == true then
            result[k] = true
        end
    end

    -- Add all entries from y to result
    for k, v in pairs(y) do
        if v == true then
            result[k] = true
        end
    end

    return result
end

-- Refresh the Tree-sitter parser and reparse if the tree looks out of sync
function M.refresh_parser(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
    if not ok or not parser then
        return
    end

    local trees = parser:parse()
    local tree = trees and trees[1]
    if not tree then
        return
    end

    local root = tree:root()
    if not root then
        return
    end

    local _, _, end_row = root:range()
    local line_count = vim.api.nvim_buf_line_count(bufnr)

    -- If the root does not span (almost) the whole buffer, force a full reparse
    if end_row < line_count - 1 or end_row > line_count + 5 then
        parser:invalidate(true)
        parser:parse()
    end
end

return M
