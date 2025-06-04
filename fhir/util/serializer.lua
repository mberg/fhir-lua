local S = {}
local function deep(o)
  if type(o)~="table" then return o end
  local n={} for k,v in pairs(o) do n[k]=deep(v) end; return n
end
S.deep_copy = deep
function S.get_by_path(t, p, d)
  local cur = t
  for seg in p:gmatch("[^.]+") do
    if type(cur) == "table" then
      cur = cur[seg]
    else
      return d
    end
  end
  if cur == nil then
    return d
  end
  return cur
end
function S.set_by_path(t, p, v)
  local cur=t; local parts={}; for s in p:gmatch("[^.]+") do parts[#parts+1]=s end
  for i=1,#parts-1 do local s=parts[i]; cur[s]=cur[s] or {}; cur=cur[s] end; cur[parts[#parts]]=v
end
return S
