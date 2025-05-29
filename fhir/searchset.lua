local Params    = require("fhir.util.params")
local Resource  = require("fhir.resource")
local SearchSet = {}
SearchSet.__index = SearchSet

function SearchSet.new(client, rt)
  local self = setmetatable({}, SearchSet)
  self.client, self.resourceType, self.params = client, rt, {}
  self._limit, self._sort = nil, nil
  return self
end
function SearchSet:search(t) for k,v in pairs(t) do self.params[k]=v end; return self end
function SearchSet:limit(n) self._limit=n; return self end
function SearchSet:sort(f)  self._sort=f;  return self end
function SearchSet:_qs()
  local q = Params.encode(self.params)
  if self._limit then q = q .. "&_count=" .. self._limit end
  if self._sort  then q = q .. "&_sort="  .. self._sort  end
  return q
end
function SearchSet:fetch()
  local bundle = self.client.http:get("/"..self.resourceType.."?"..self:_qs())
  return bundle
end
function SearchSet:first()
  self:limit(1)
  local b = self:fetch()
  if b and b.entry and b.entry[1] then
    return Resource:new(self.resourceType, b.entry[1].resource)
  end
end
return SearchSet 