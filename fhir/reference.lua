local Resource  = require("fhir.resource")
local Reference = {}
Reference.__index = Reference
function Reference.new(client, rt, id)
  return setmetatable({ client=client, resourceType=rt, id=id }, Reference)
end
function Reference:to_resource() return self.client:get(self.resourceType, self.id) end
function Reference:delete()      return self.client:delete(self.resourceType, self.id) end
function Reference:as_string()   return self.resourceType.."/"..self.id end
return Reference 