local json  = require("cjson.safe")
local http  = require("socket.http")
local ltn12 = require("ltn12")

local Http  = {}; Http.__index = Http
function Http.new(base, def, opts)
  return setmetatable({ base=base:gsub("/*$",""), def=def or {}, opts=opts or {} }, Http)
end
local function hdr(defaults, extra)
  local h = { ["content-type"]="application/fhir+json", accept="application/fhir+json" }
  for k,v in pairs(defaults) do h[k:lower()]=v end
  for k,v in pairs(extra or {}) do h[k:lower()]=v end
  return h
end
function Http:_req(method, path, body)
  local resp = {}
  local payload = body and json.encode(body)
  local _, code, rh = http.request{
    method  = method,
    url     = self.base .. path,
    headers = hdr(self.def),
    source  = payload and ltn12.source.string(payload) or nil,
    sink    = ltn12.sink.table(resp),
  }
  local raw = table.concat(resp)
  local data = (#raw>0) and json.decode(raw) or {}
  if code >= 400 then error({ status=code, body=data, headers=rh }) end
  return data, rh
end
for _,m in ipairs{"get","post","put","patch","delete"} do
  Http[m] = function(self, p, b) return self:_req(m:upper(), p, b) end
end
return Http 