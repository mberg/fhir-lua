local Http        = require("fhir.util.http")
local Resource    = require("fhir.resource")
local SearchSet   = require("fhir.searchset")
local Reference   = require("fhir.reference")

local Client = {}
Client.__index = Client

function Client.new(opts)
  assert(opts and opts.baseUrl, "baseUrl required")
  local self = setmetatable({}, Client)
  self.baseUrl = opts.baseUrl:gsub("/*$", "")
  self.headers = opts.headers or {}
  self.http    = Http.new(self.baseUrl, self.headers, opts.http_options)
  self.mode    = opts.mode or "sync"
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

return Client 