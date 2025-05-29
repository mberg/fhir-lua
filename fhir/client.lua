local Http        = require("fhir.util.http")
local Resource    = require("fhir.resource")
local SearchSet   = require("fhir.searchset")
local Reference   = require("fhir.reference")

local Client = {}
Client.__index = Client

function Client.new(opts)
  assert(opts, "Configuration options required")
  
  local self = setmetatable({}, Client)
  self.mode = opts.mode or "sync"
  
  -- Backend selection
  if opts.backend == "google_healthcare" then
    local GoogleHealthcare = require("fhir.backends.google_healthcare")
    assert(opts.google_config, "google_config required for Google Healthcare backend")
    self.http = GoogleHealthcare.new(opts.google_config)
    self.baseUrl = "google_healthcare://" .. opts.google_config.project_id
    
    -- Extend client with Google-specific methods
    local GoogleClient = require("fhir.backends.google_client")
    GoogleClient.extend_client(self)
  else
    -- Default to standard HTTP backend
    assert(opts.baseUrl, "baseUrl required for standard HTTP backend")
    self.baseUrl = opts.baseUrl:gsub("/*$", "")
    self.headers = opts.headers or {}
    self.http = Http.new(self.baseUrl, self.headers, opts.http_options)
  end
  
  return self
end

local function path(rt, id) return "/" .. rt .. (id and ("/"..id) or "") end

-- CRUD --------------------------------------------------------
function Client:create(resource)
  local data = resource:serialize()
  local body = self.http:post(path(resource.resourceType), data)
  if body.id then resource.id = body.id end
  return resource, body
end

function Client:save(resource)
  assert(resource.id, "resource.id required for save")
  local body = self.http:put(path(resource.resourceType, resource.id), resource:serialize())
  return resource, body
end

function Client:get(rt, id)
  local data = self.http:get(path(rt, id))
  return Resource:new(rt, data)
end

function Client:patch(rt, id, patchBody)
  return self.http:patch(path(rt, id), patchBody)
end

function Client:delete(rt, id)
  return self.http:delete(path(rt, id))
end

-- Search builder ---------------------------------------------
function Client:resources(rt)  return SearchSet.new(self, rt) end

-- Reference helper -------------------------------------------
function Client:reference(rt, id) return Reference.new(self, rt, id) end

-- Backend-specific helper methods
function Client:is_google_healthcare()
  return self.baseUrl and self.baseUrl:match("^google_healthcare://")
end

return Client 