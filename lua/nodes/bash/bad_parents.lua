-- Nodes with these parents are nested fragments and should not be sent alone.
return {
  ["command"] = true,
  ["pipeline"] = true,
  ["list"] = true,
  ["word"] = true,
  ["string"] = true,
  ["raw_string"] = true,
  ["concatenation"] = true,
  ["command_substitution"] = true,
  ["process_substitution"] = true,
  ["arithmetic_expansion"] = true,
  ["expansion"] = true,
  ["simple_expansion"] = true,
  ["heredoc_body"] = true,
}
