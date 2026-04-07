local M = {}

function M.send(text, opts)
  opts = opts or {}

  local payload = tostring(text or "")
  if payload == "" then
    return { ok = false, reason = "empty_payload" }
  end

  local append_newline = opts.append_newline ~= false
  if append_newline and payload:sub(-1) ~= "\n" then
    payload = payload .. "\n"
  end

  local send_fn = vim.fn["slime#send"]
  if type(send_fn) ~= "function" then
    return { ok = false, reason = "slime_unavailable" }
  end

  local ok, err = pcall(send_fn, payload)
  if not ok then
    return { ok = false, reason = "slime_send_failed", error = tostring(err) }
  end

  return {
    ok = true,
    reason = "ok",
    backend = "slime",
    enqueued = false,
    queue_depth = 0,
  }
end

return M
