local Client = require("fhir.client") -- This will ensure dotenv is loaded via client.lua

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
  setmetatable(self, AsyncClient)
  
  -- If this is a Google Healthcare client, make the Google-specific methods async too
  if self:is_google_healthcare() then
    local google_methods = {"google_search", "google_create_resource", "google_get_resource", 
                           "google_update_resource", "google_delete_resource"}
    
    for _, method_name in ipairs(google_methods) do
      if self[method_name] then
        local original_method = self[method_name]
        self[method_name] = function(self_instance, ...)
          return asyncify(self_instance, original_method, ...)
        end
      end
    end
  end
  
  return self
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