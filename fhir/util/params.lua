local enc=function(s) return (s:gsub("([^%w%-%_%.%~])", function(c) return string.format("%%%02X", string.byte(c)) end)) end
local P={} ; local function pair(k,v) return enc(k).."="..enc(v) end
function P.encode(t)
  local prts={}
  local function add(k,v) prts[#prts+1]=pair(k,v) end
  for k,v in pairs(t) do if type(v)=="table" then for _,i in ipairs(v) do add(k,tostring(i)) end else add(k,tostring(v)) end end
  return table.concat(prts,"&")
end
return P 