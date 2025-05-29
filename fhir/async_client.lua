local Client = require("fhir.client")
local AsyncClient = {}
AsyncClient.__index = AsyncClient
setmetatable(AsyncClient, { __index = Client })

local coroutine = coroutine

local function asyncify(self, fn, ...)
  local args = { ... }
  return coroutine.wrap(function() return fn(self, table.unpack(args)) end)
end

function AsyncClient.new(opts)
  opts = opts or {}
  opts.mode = "async"
  local self = Client.new(opts)
  return setmetatable(self, AsyncClient)
end

for _, m in ipairs({"create", "save", "get", "patch", "delete"}) do
  AsyncClient[m] = function(self, ...)
    return asyncify(self, Client[m], ...)
  end
end

function AsyncClient:resources(rt)
  local ss      = Client.resources(self, rt)
  local fetch   = ss.fetch
  local first   = ss.first
  ss.fetch = function(s)
    return coroutine.wrap(function() return fetch(s) end)
  end
  ss.first = function(s)
    return coroutine.wrap(function() return first(s) end)
  end
  return ss
end

return AsyncClient 