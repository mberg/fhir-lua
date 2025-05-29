--[[
FHIR Async Client Module

This module provides an AsyncClient class that extends the base FHIR Client with
asynchronous functionality using Lua coroutines. It wraps all client methods to
return coroutine functions that can be yielded from, enabling non-blocking operations.

The AsyncClient maintains full compatibility with the synchronous Client interface
while providing async variants of all CRUD operations, search functionality, and
backend-specific methods (including Google Healthcare API operations).
]]--

local Client = require("fhir.client") -- This will ensure dotenv is loaded via client.lua

local AsyncClient = {}
AsyncClient.__index = AsyncClient
setmetatable(AsyncClient, { __index = Client })

local coroutine = coroutine

--[[
Wraps a synchronous function to return a coroutine that can be yielded from

@param self (AsyncClient): The async client instance
@param fn (function): The synchronous function to wrap
@param ... (any): Arguments to pass to the function
@return (function): A coroutine wrapper function
]]--
local function asyncify(self, fn, ...)
  local args = { ... }
  return coroutine.wrap(function()
    return fn(self, table.unpack(args))
  end)
end

--[[
Creates a new AsyncClient instance with asynchronous capabilities

@param opts (table, optional): Configuration options (same as Client.new)
@return (AsyncClient): A new AsyncClient instance with async method variants
]]--
function AsyncClient.new(opts)
  opts = opts or {}
  opts.mode = "async"
  local self = Client.new(opts)
  setmetatable(self, AsyncClient)
  
  -- If this is a Google Healthcare client, make the Google-specific methods async too
  if self:is_google_healthcare() then
    local google_methods = {
      "google_search", "google_create_resource", "google_get_resource", 
      "google_update_resource", "google_delete_resource"
    }
    
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

-- Create async versions of all CRUD methods
for _, m in ipairs({"create", "save", "get", "patch", "delete"}) do
  AsyncClient[m] = function(self, ...)
    return asyncify(self, Client[m], ...)
  end
end

--[[
Creates an async-enabled SearchSet for building and executing search queries

@param rt (string): The resource type to search for
@return (SearchSet): A SearchSet with async fetch and first methods
]]--
function AsyncClient:resources(rt)
  local ss = Client.resources(self, rt)
  local fetch = ss.fetch
  local first = ss.first
  
  -- Wrap the SearchSet's fetch and first methods to be async
  ss.fetch = function(s)
    return coroutine.wrap(function()
      return fetch(s)
    end)
  end
  
  ss.first = function(s)
    return coroutine.wrap(function()
      return first(s)
    end)
  end
  
  return ss
end

return AsyncClient 