--[[
FHIR SearchSet Module

This module provides a SearchSet class for building and executing FHIR search queries.
It offers a fluent interface for constructing search parameters, applying limits and sorting,
and retrieving results as FHIR Bundle resources or individual Resource instances.

The SearchSet class acts as a query builder that works with a FHIR Client to execute
searches against FHIR servers with proper parameter encoding and result handling.
]]--

local Params = require("fhir.util.params")
local Resource = require("fhir.resource")

local SearchSet = {}
SearchSet.__index = SearchSet

--[[
Creates a new SearchSet instance for building search queries

@param client (Client): The FHIR client instance to use for HTTP requests
@param rt (string): The resource type to search for (e.g., "Patient", "Observation")
@return (SearchSet): A new SearchSet instance for the specified resource type
]]--
function SearchSet.new(client, rt)
  local self = setmetatable({}, SearchSet)
  self.client, self.resourceType, self.params = client, rt, {}
  self._limit, self._sort = nil, nil
  return self
end

--[[
Adds search parameters to the query using a fluent interface

@param t (table): A table of search parameter key-value pairs
@return (SearchSet): Returns self to enable method chaining
]]--
function SearchSet:search(t)
  for k, v in pairs(t) do
    self.params[k] = v
  end
  return self
end

--[[
Sets a limit on the number of results to return

@param n (number): Maximum number of results to return
@return (SearchSet): Returns self to enable method chaining
]]--
function SearchSet:limit(n)
  self._limit = n
  return self
end

--[[
Sets the sort field for the search results

@param f (string): Field name to sort by
@return (SearchSet): Returns self to enable method chaining
]]--
function SearchSet:sort(f)
  self._sort = f
  return self
end

--[[
Builds the query string from search parameters, limit, and sort options

@return (string): URL-encoded query string with all search parameters
]]--
function SearchSet:_qs()
  local q = Params.encode(self.params)
  if self._limit then
    q = q .. "&_count=" .. self._limit
  end
  if self._sort then
    q = q .. "&_sort=" .. self._sort
  end
  return q
end

--[[
Executes the search query and returns the raw FHIR Bundle

@return (table): The FHIR Bundle containing search results
]]--
function SearchSet:fetch()
  local bundle = self.client.http:get("/" .. self.resourceType .. "?" .. self:_qs())
  return bundle
end

--[[
Executes the search with a limit of 1 and returns the first result as a Resource

@return (Resource|nil): The first matching resource, or nil if no results found
]]--
function SearchSet:first()
  self:limit(1)
  local b = self:fetch()
  if b and b.entry and b.entry[1] then
    return Resource:new(self.resourceType, b.entry[1].resource)
  end
end

return SearchSet 