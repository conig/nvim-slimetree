local M = {}

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
function M.start_goo(commands, window_name)
	window_name = window_name or "gooTabs"
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
        end

	-- Retrieve pane IDs
	local panes_output = exec_cmd(string.format("tmux list-panes -t %s:%s -F '#{pane_id}'", session_name, window_name))
	if not panes_output or panes_output == "" then
		vim.notify("Failed to retrieve pane IDs.", vim.log.levels.ERROR)
		return {}
	end

	local pane_ids = {}
	for pane_id in panes_output:gmatch("[^\r\n]+") do
		table.insert(pane_ids, pane_id)
	end

	-- Ensure we have exactly 4 panes
	if #pane_ids ~= 4 then
		vim.notify(string.format("Expected 4 panes, but found %d panes.", #pane_ids), vim.log.levels.ERROR)
		return {}
	end

	-- Store pane IDs in environment variables
	for i, pane_id in ipairs(pane_ids) do
		vim.fn.setenv(string.format("%s_%d", window_name, i), pane_id)
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
	local panes_output = exec_cmd("tmux list-panes -a -F '#{pane_id}'")
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
function M.end_goo(window_name)
	window_name = window_name or "gooTabs"

	-- Retrieve pane IDs from environment variables
	local pane_ids = {}
	for i = 1, 4 do
		local pane_id = vim.fn.getenv(string.format("%s_%d",window_name, i))
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
		vim.fn.setenv(string.format("%s_%d", window_name, i), nil)
	end

	vim.notify("All goo panes and the '" .. window_name .. "' window have been closed.", vim.log.levels.INFO)
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
function M.summon_goo(n, window_name)
  window_name = window_name or "gooTabs"
	-- Ensure 'n' is between 1 and 4
	if type(n) ~= "number" or n < 1 or n > 4 then
		vim.notify("Please provide a pane number between 1 and 4.", vim.log.levels.ERROR)
		return
	end

	local pane_id = vim.fn.getenv(string.format("%s_%d", window_name, n))
	if not pane_id or pane_id == "" then
		vim.notify("Pane ID not found. Make sure to run :StartGoo first.", vim.log.levels.ERROR)
		return
	end

	-- Get the current window name
	local current_window = exec_cmd("tmux display-message -p '#{window_name}'")
	if not current_window then
		vim.notify("Failed to retrieve current window name.", vim.log.levels.ERROR)
		return
	end
	current_window = current_window:gsub("%s+", "") -- Trim whitespace

	-- Prevent moving panes within the gooTabs window
	if current_window == window_name then
		vim.notify("Cannot summon panes within the 'gooTabs' window.", vim.log.levels.WARN)
		return
	end

	-- Move all goo panes back to 'gooTabs' (except those already there)
	local panes_moved_back = false
	for i = 1, 4 do
		local pid = vim.fn.getenv(string.format("%s_%d", window_name, i))
		if pid and pid ~= "" then
			-- Get the window name of the pane
			local pane_window = get_pane_window(pid)
			if pane_window and pane_window ~= window_name then
				-- Move the pane back to 'gooTabs' without changing focus
				local move_cmd = string.format("tmux move-pane -d -s %s -t " .. window_name .. "", pid)
				local move_output = exec_cmd(move_cmd)
				if move_output == nil then
					vim.notify(string.format("Failed to move pane %s back to " .. window_name .. "'.", pid), vim.log.levels.ERROR)
				else
					-- vim.notify(string.format("Moved pane %s back to 'gooTabs'.", pid), vim.log.levels.INFO)
					panes_moved_back = true
				end
			end
		end
	end

	-- Reset the layout in 'gooTabs' if any panes were moved back
	if panes_moved_back then
		local layout_cmd = "tmux select-layout -t " .. window_name .. " even-horizontal"
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
	local summon_cmd = string.format("tmux join-pane -h -d -s %s -t %s -l 33%%", pane_id, current_window)
	os.execute(summon_cmd)
	_G.goo_started = true
	-- vim.notify(string.format("Summoned pane %d (%s) to window '%s' to the right.", n, pane_id, current_window), vim.log.levels.INFO)
end

return M

