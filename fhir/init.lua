local _M = {}
setmetatable(_M, {
  __index = function(self, key)
    local ok, mod = pcall(require, "fhir." .. key)
    if ok then
      rawset(self, key, mod)
      return mod
    end
    error("fhir module '" .. key .. "' not found: " .. tostring(mod))
  end,
})
return _M 