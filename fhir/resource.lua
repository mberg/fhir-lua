--[[
FHIR Resource Module

This module provides a base Resource class for FHIR (Fast Healthcare Interoperability Resources).
It offers a simple interface for creating, manipulating, and serializing FHIR resources
using path-based operations through the Serializer utility.

The Resource class acts as a wrapper around FHIR resource data, providing convenient
methods for accessing nested fields and maintaining the resource structure.
]]--

local Serializer = require("fhir.util.serializer")

local Resource = {}
Resource.__index = Resource

--[[
Creates a new FHIR Resource instance

@param rt (string): The resource type (e.g., "Patient", "Observation", etc.)
@param fields (table, optional): Initial field values for the resource
@return (Resource): A new Resource instance with the specified type and fields
]]--
function Resource:new(rt, fields)
  local obj = fields or {}
  obj.resourceType = rt
  return setmetatable(obj, self)
end

--[[
Retrieves a value from the resource using a path-based accessor

@param path (string): Dot-separated path to the desired field (e.g., "name.0.given.0")
@param def (any, optional): Default value to return if the path doesn't exist
@return (any): The value at the specified path, or the default value if not found
]]--
function Resource:get(path, def)
  return Serializer.get_by_path(self, path, def)
end

--[[
Sets a value in the resource using a path-based accessor

@param path (string): Dot-separated path where the value should be set
@param val (any): The value to set at the specified path
]]--
function Resource:set(path, val)
  Serializer.set_by_path(self, path, val)
end

--[[
Creates a deep copy of the resource for serialization

@return (table): A deep copy of the resource data suitable for serialization
]]--
function Resource:serialize()
  return Serializer.deep_copy(self)
end

return Resource 