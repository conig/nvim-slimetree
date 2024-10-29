
local M = {}

-- Issues
-- When there are multiple nodes blocks on the same line. Only assess the eligibility of the one with the largest width. Otherwise assignments won't be fully considered instead opting for their atomic constituents.
-- When there there are multiple eligble nodes that BEGIN on the same line, choose the one with the longest width. Otherwise full blocks will not be exceuted properly.

--- EXPERIMENTAL CODE
local treesitter = vim.treesitter
local ts_utils = require("nvim-treesitter.ts_utils")

-- Define acceptable Tree-sitter node types for chunking
local acceptable_node_types = {
    ["call"] = true,
    ["function_definition"] = true,
    ["return_statement"] = true,
    ["table_constructor"] = true,
    ["expression_list"] = true,
    ["assignment_statement"] = true,
    ["extract_operator"] = true,
    ["function_call"] = true,
    ["if_statement"] = true,
    ["for_statement"] = true,
    ["while_statement"] = true,
    ["braced_expression"] = true,
    ["expression_statement"] = true,
    ["binary_operator"] = true,  -- Corrected from "binary_expression"
    ["unary_expression"] = true,
    ["literal"] = true,
    ["float"] = true,
    ["subset"] = true,
    ["identifier"] = true,
    ["local_declaration"] = true,
    ["repeat_statement"] = true,
    -- Add more node types as needed for your language
}

-- Define nodes to be skipped (e.g., comments, whitespace)
local skip_nodes = {
    ["comment"] = true,
    ["fenced_code_block"] = true,
    ["fenced_code_block_delimiter"] = true,
    ["inline"] = true,
    ["minus_metadata"] = true,
    ["atx_h1_marker"] = true,
    ["atx_h2_marker"] = true,
    ["atx_h3_marker"] = true,
    ["atx_h4_marker"] = true,
    ["atx_h5_marker"] = true,
    -- Add more node types to skip as needed
}

local function get_node_under_cursor(bufnr, row, col)
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
    local line = lines[1] or ''
    if line == '' then
        vim.notify("The specified row is empty.", vim.log.levels.INFO)
        return nil
    end

    -- Get the column position of the first non-whitespace character
    local start_col = (line:find("%S") or 1) - 1 -- 0-based indexing

    local col = start_col
    local line_length = #line

    -- While not at the end of the line
    while col < line_length do
        -- Retrieve node at current position
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
                while col < line_length and line:sub(col + 1, col + 1):match('%s') do
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
        if span > max_span then
            max_span = span
            widest_node = n
        end
    end

    if widest_node then
        -- Print the node type and its column span
        local _, start_col_node, _, end_col_node = widest_node:range()
        -- vim.notify(string.format(
        --     "Widest node type: %s (columns %d to %d, span %d)",
        --     widest_node:type(), start_col_node, end_col_node, max_span
        -- ))
    else
        -- vim.notify("No Tree-sitter nodes found on this row.", vim.log.levels.INFO)
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

-- Utility function to check if a node is acceptable
local function is_acceptable_node(node)
    local node_type = node:type()
    if acceptable_node_types[node_type] then
        -- Check if any ancestor is of type 'argument' or 'call', but stop at 'program'
        local parent = node:parent()
        while parent and parent:type() ~= 'program' and parent:type() ~= 'chunk' and parent:type() ~= "braced_expression" do
            if parent:type() == 'argument' or parent:type() == 'binary_operator' then
                return false  -- Node is part of an argument, not acceptable
            end
            -- if(parent:type() == 'binary_operator') then
            --     return false
            -- end
            parent = parent:parent()
        end
        return true  -- Node is acceptable
    else
        return false  -- Node type is not acceptable
    end
end

-- Utility function to check if a node type should be skipped
local function is_skip_node(node_type)
    return skip_nodes[node_type] or false
end

-- Function to traverse upwards and find the smallest acceptable node
local function find_smallest_acceptable_node(node)
    while node do
        if is_acceptable_node(node) then
            return node
        end
        node = node:parent()
    end
    return nil
end

-- Function to find the next acceptable node below the current position
local function find_next_acceptable_node(bufnr, current_row, current_col)
    local parser = vim.treesitter.get_parser(bufnr)
    local tree = parser:parse()[1]
    if not tree then return nil end

    -- Get the node under the cursor
    local node = get_node_under_cursor(bufnr, current_row, current_col)
    if not node then return nil end

    -- Find the 'program' node that contains the cursor
    local root = node
    while root and root:type() ~= 'program' do
        root = root:parent()
    end

    if not root then
        -- If no 'program' node is found, default to the full tree root
        root = tree:root()
    end

    local found_nodes = {}

    -- Helper function to recursively gather all nodes
    local function gather_nodes(node)
        -- Skip nodes that should be skipped
        if is_skip_node(node:type()) then
            return
        end

        local start_row, start_col, end_row, end_col = node:range()

        -- Check if the node is acceptable
        if is_acceptable_node(node) then
            table.insert(found_nodes, node)
        end

        -- Recursively gather all child nodes
        for child in node:iter_children() do
            gather_nodes(child)
        end
    end

    -- Gather all nodes starting from the 'program' node
    gather_nodes(root)

    -- Filter nodes that are after the current cursor position
    local filtered_nodes = {}
    for _, node in ipairs(found_nodes) do
        local start_row, start_col = node:range()

        -- Ensure the node is after the current cursor position
        if (start_row > current_row) or
           (start_row == current_row and start_col > current_col) then
            table.insert(filtered_nodes, node)
        end
    end

    -- Sort the filtered nodes by their starting position
    table.sort(filtered_nodes, function(a, b)
        local a_start_row, a_start_col = a:range()
        local b_start_row, b_start_col = b:range()
        if a_start_row == b_start_row then
            return a_start_col < b_start_col
        else
            return a_start_row < b_start_row
        end
    end)

    -- Return the closest acceptable node below
    return filtered_nodes[1]
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
    if(_G.goo_started == false and _G.use_goo == true) then
        vim.notify("Please start goo first", vim.log.levels.ERROR)
        return
    end
    local hold_position = hold_position or false 
    -- Get the current buffer and cursor position
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0) -- {row, col}
    local row = cursor[1] - 1 -- Convert to 0-based
    local col = cursor[2]
    local last_line = vim.api.nvim_buf_line_count(bufnr) - 1

     while row < last_line do
        local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
        local is_empty = line:match("^%s*$") ~= nil
        
        -- Get treesitter node at current position
        local node = vim.treesitter.get_node({
            bufnr = bufnr,
            pos = {row, 0}
        })
        
        local node_type = node and node:type() or nil
        local should_skip = is_empty or (node_type and skip_nodes[node_type])
        
        if not should_skip then
            vim.api.nvim_win_set_cursor(0, {row + 1, cursor[2]})
            break
        end
        row = row + 1
    end

    -- Retrieve the current line's content
    local current_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]

    -- Check if the current line is entirely empty
    local is_line_empty = current_line:match("^%s*$") ~= nil

    local node = get_node_under_cursor(bufnr, row, col)
    if not node then
        -- vim.notify("No Tree-sitter node found under the cursor.", vim.log.levels.WARN)
        return
    end

    -- Check if the current node is a skip node (e.g., comment)
    local node_type = node:type()
    local is_skip = is_skip_node(node_type)

    if is_line_empty or is_skip then
        -- If the line is empty or a skip node, search for the next acceptable node below
        local acceptable_node = find_next_acceptable_node(bufnr, row, col)
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
            node = get_node_under_cursor(bufnr, row, col)
            if not node then
                -- vim.notify("No Tree-sitter node found after moving cursor.", vim.log.levels.WARN)
                return
            end

            node_type = node:type()
            is_skip = is_skip_node(node_type)
            if is_skip then
                -- If the new node is a skip node, treat it like an empty line
                local acceptable_node = find_next_acceptable_node(bufnr, row, col)
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
    local acceptable_node = find_smallest_acceptable_node(node)

    if acceptable_node then
        -- Ensure that if the node starts after the cursor's column on the same line, we still consider it
        local start_row, start_col, end_row, end_col = acceptable_node:range()
        if start_row == row and start_col > col then
            -- The acceptable node starts after the cursor's column, so treat it as the next acceptable node
            acceptable_node = find_next_acceptable_node(bufnr, row, col)
            if not acceptable_node then
                -- vim.notify("No acceptable chunk found after the cursor.", vim.log.levels.INFO)
                return
            end
        end
    else
        -- If current node isn't acceptable, search for the next acceptable node below
        acceptable_node = find_next_acceptable_node(bufnr, row, col)
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

-- EXPERIMENTAL CODE END

-- 
-- Helper function to execute a shell command and return its output
--
local function exec_cmd(cmd)
  local result = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error
  if exit_code ~= 0 then
    vim.notify(string.format("Failed to execute command: %s\nError: %s", cmd, result), vim.log.levels.ERROR)
    return nil
  end
  return result
end

-- Function to escape special characters in Lua patterns
local function escape_lua_pattern(s)
  return (s:gsub("([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"))
end

-- Function to create the gooTabs window with 4 panes
function M.start_goo(commands)
  local window_name = "gooTabs"
 -- Retrieve the current session name
  local session_name = exec_cmd("tmux display-message -p '#S'"):gsub("\n", "")
  if not session_name or session_name == "" then
    vim.notify("Failed to retrieve tmux session name.", vim.log.levels.ERROR)
    return {}
  end

  -- escape spaces in session name if present so tmux can interpret it as a single  argument
  session_name = session_name:gsub(" ", "\\ ")
  -- Check if 'gooTabs' window exists
  local list_windows_cmd = string.format("tmux list-windows -t %s -F '#{window_name}'", session_name)
  local windows_output = exec_cmd(list_windows_cmd)
  local window_exists = false

  if windows_output then
    for window in windows_output:gmatch("[^\r\n]+") do
      if window == window_name then
        window_exists = true
        break
      end
    end
  end

  if window_exists then
    -- 'gooTabs' window exists, proceed to kill it
    local kill_cmd = string.format("tmux kill-window -t %s:%s", session_name, window_name)
    exec_cmd(kill_cmd)
    -- Optional: Notify the user
    -- vim.notify("Existing 'gooTabs' window killed.", vim.log.levels.INFO)
  end

  -- Create a new tmux window named 'gooTabs' in detached mode
  local create_cmd = string.format("tmux new-window -d -n %s -t %s:", window_name, session_name)
  local create_output = exec_cmd(create_cmd)
  if not create_output then
    vim.notify("Failed to create new window. Command output: " .. tostring(create_output), vim.log.levels.ERROR)
    return {}
  end

  -- Split the initial pane vertically 3 times to create 4 vertical panes
  local initial_pane = string.format("%s:%s.0", session_name, window_name)

  for i = 1, 3 do
    local split_cmd = string.format("tmux split-window -h -t %s", initial_pane)
    local split_output = exec_cmd(split_cmd)
    if not split_output then
      vim.notify("Failed to split pane with command: " .. split_cmd, vim.log.levels.ERROR)
      return {}
    end
    -- Optional: brief sleep to allow tmux to process the split
    vim.cmd "sleep 50ms"
  end

  -- Retrieve pane IDs
  local panes_output = exec_cmd(string.format("tmux list-panes -t %s:%s -F '#{pane_id}'", session_name, window_name))
  if not panes_output or panes_output == "" then
    vim.notify("Failed to retrieve pane IDs.", vim.log.levels.ERROR)
    return {}
  end

  local pane_ids = {}
  for pane_id in panes_output:gmatch "[^\r\n]+" do
    table.insert(pane_ids, pane_id)
  end

  -- Ensure we have exactly 4 panes
  if #pane_ids ~= 4 then
    vim.notify(string.format("Expected 4 panes, but found %d panes.", #pane_ids), vim.log.levels.ERROR)
    return {}
  end

  -- Store pane IDs in environment variables
  for i, pane_id in ipairs(pane_ids) do
    vim.fn.setenv(string.format("GOO_PANE_%d", i), pane_id)
  end

  -- Send commands to panes
  for i, pane_id in ipairs(pane_ids) do
    local cmd_to_run = nil
    if commands then
      if type(commands) == "table" then
        cmd_to_run = commands[i] or ""
      else
        cmd_to_run = commands
      end
    else
      cmd_to_run = "" -- No command, or default command
    end

    if cmd_to_run and cmd_to_run ~= "" then
      local send_cmd = string.format("tmux send-keys -t %s '%s' Enter", pane_id, cmd_to_run)
      local send_output = exec_cmd(send_cmd)
      if not send_output then
        vim.notify("Failed to send command to pane with command: " .. send_cmd, vim.log.levels.ERROR)
      end
    end
  end

  -- vim.notify("gooTabs window with 4 vertical panes created successfully.", vim.log.levels.INFO)
  return pane_ids
end

-- Function to check if a pane exists
local function pane_exists(pane_id)
  local panes_output = exec_cmd "tmux list-panes -a -F '#{pane_id}'"
  if not panes_output then
    return false
  end
  -- Escape special characters in pane_id
  local escaped_pane_id = escape_lua_pattern(pane_id)
  if panes_output:find(escaped_pane_id) then
    return true
  else
    return false
  end
end

-- Function to end goo session by killing panes and the gooTabs window
function M.end_goo()
  local window_name = "gooTabs"

  -- Retrieve the current session name
  local session_name = exec_cmd("tmux display-message -p '#S'"):gsub("\n", "")

  -- Retrieve pane IDs from environment variables
  local pane_ids = {}
  for i = 1, 4 do
    local pane_id = vim.fn.getenv(string.format("GOO_PANE_%d", i))
    if pane_id and pane_id ~= "" then
      table.insert(pane_ids, pane_id)
    end
  end

  -- Kill each pane if it exists
  for _, pane_id in ipairs(pane_ids) do
    if pane_exists(pane_id) then
      local kill_cmd = string.format("tmux kill-pane -t %s", pane_id)
      local kill_output = exec_cmd(kill_cmd)
      if not kill_output then
        vim.notify("Failed to kill pane " .. pane_id, vim.log.levels.ERROR)
      end
    end
  end

    -- Unset the environment variables
  for i = 1, 4 do
    vim.fn.setenv(string.format("GOO_PANE_%d", i), nil)
  end

  vim.notify("All goo panes and the 'gooTabs' window have been closed.", vim.log.levels.INFO)
end

-- Function to summon a specific goo pane into the current window
-- Helper function to get the window name of a given pane
local function get_pane_window(pane_id)
  local output = exec_cmd(string.format("tmux display-message -p -t %s '#{window_name}'", pane_id))
  if output then
    return output:gsub("%s+", "") -- Trim whitespace
  else
    return nil
  end
end

-- Function to summon a specific goo pane into the current window
function M.summon_goo(n)
  -- Ensure 'n' is between 1 and 4
  if type(n) ~= "number" or n < 1 or n > 4 then
    vim.notify("Please provide a pane number between 1 and 4.", vim.log.levels.ERROR)
    return
  end

  local pane_id = vim.fn.getenv(string.format("GOO_PANE_%d", n))
  if not pane_id or pane_id == "" then
    vim.notify("Pane ID not found. Make sure to run :StartGoo first.", vim.log.levels.ERROR)
    return
  end

  -- Get the current window name
  local current_window = exec_cmd "tmux display-message -p '#{window_name}'"
  if not current_window then
    vim.notify("Failed to retrieve current window name.", vim.log.levels.ERROR)
    return
  end
  current_window = current_window:gsub("%s+", "") -- Trim whitespace

  -- Prevent moving panes within the gooTabs window
  if current_window == "gooTabs" then
    vim.notify("Cannot summon panes within the 'gooTabs' window.", vim.log.levels.WARN)
    return
  end

  -- Move all goo panes back to 'gooTabs' (except those already there)
  local panes_moved_back = false
  for i = 1, 4 do
    local pid = vim.fn.getenv(string.format("GOO_PANE_%d", i))
    if pid and pid ~= "" then
      -- Get the window name of the pane
      local pane_window = get_pane_window(pid)
      if pane_window and pane_window ~= "gooTabs" then
        -- Move the pane back to 'gooTabs' without changing focus
        local move_cmd = string.format("tmux move-pane -d -s %s -t gooTabs", pid)
        local move_output = exec_cmd(move_cmd)
        if move_output == nil then
          vim.notify(string.format("Failed to move pane %s back to 'gooTabs'.", pid), vim.log.levels.ERROR)
        else
          -- vim.notify(string.format("Moved pane %s back to 'gooTabs'.", pid), vim.log.levels.INFO)
          panes_moved_back = true
        end
      end
    end
  end

  -- Reset the layout in 'gooTabs' if any panes were moved back
  if panes_moved_back then
    local layout_cmd = "tmux select-layout -t gooTabs even-horizontal"
    exec_cmd(layout_cmd)
    -- vim.notify("Reset 'gooTabs' layout to even-horizontal.", vim.log.levels.INFO)
  end

  -- Now, check if the desired pane is already in the current window
  local pane_window = get_pane_window(pane_id)
  if pane_window == current_window then
    vim.notify(string.format("Pane %d is already in the current window.", n), vim.log.levels.INFO)
    return
  end

  -- Bring the specified pane into the current window to the right without changing focus
  local summon_cmd = string.format("tmux join-pane -h -d -s %s -t %s -l 30%%", pane_id, current_window)
  os.execute(summon_cmd)
  _G.goo_started = true
  -- vim.notify(string.format("Summoned pane %d (%s) to window '%s' to the right.", n, pane_id, current_window), vim.log.levels.INFO)
end

function M.goo_send(text)
  vim.fn["slime#send"](text .. "\n")
end


return M
