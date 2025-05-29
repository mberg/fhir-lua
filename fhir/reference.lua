--[[
FHIR Reference Module

This module provides a Reference class for handling FHIR resource references.
It offers a lightweight wrapper around resource identifiers that can be used
to fetch the actual resource, delete it, or convert it to a string representation.

The Reference class provides a convenient way to work with resource references
without immediately loading the full resource data, enabling lazy loading patterns.
]]--

local Resource = require("fhir.resource")

local Reference = {}
Reference.__index = Reference

--[[
Creates a new Reference instance pointing to a specific FHIR resource

@param client (Client): The FHIR client instance to use for operations
@param rt (string): The resource type (e.g., "Patient", "Observation")
@param id (string): The unique identifier of the resource
@return (Reference): A new Reference instance for the specified resource
]]--
function Reference.new(client, rt, id)
  return setmetatable({ client = client, resourceType = rt, id = id }, Reference)
end

--[[
Fetches and returns the actual FHIR resource that this reference points to

@return (Resource): The full FHIR resource instance
]]--
function Reference:to_resource()
  return self.client:get(self.resourceType, self.id)
end

--[[
Deletes the resource that this reference points to

@return (any): The result of the delete operation from the FHIR server
]]--
function Reference:delete()
  return self.client:delete(self.resourceType, self.id)
end

--[[
Converts the reference to its string representation in the format "ResourceType/id"

@return (string): String representation of the reference (e.g., "Patient/123")
]]--
function Reference:as_string()
  return self.resourceType .. "/" .. self.id
end

return Reference 