-- bad_parents.lua
-- nodes with these parents will always be rejected
return {
  ["argument_list"] = true,
  ["binary_operator"] = true,
}

