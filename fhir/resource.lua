local Serializer = require("fhir.util.serializer")
local Resource  = {}
Resource.__index = Resource

function Resource:new(rt, fields)
  local obj       = fields or {}
  obj.resourceType = rt
  return setmetatable(obj, self)
end
function Resource:get(path, def) return Serializer.get_by_path(self, path, def) end
function Resource:set(path, val)  Serializer.set_by_path(self, path, val)      end
function Resource:serialize()     return Serializer.deep_copy(self)            end
return Resource 