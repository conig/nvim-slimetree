local M = {}
-- logical test of whether x is container in y
function M.in_set(x, y)
        if type(y) ~= "table" then
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

return M
