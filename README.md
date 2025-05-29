# FHIR‑Lua

Early **Lua port** of the popular [fhir‑py](https://github.com/beda‑software/fhir‑py) client.
Supports:

* Synchronous client (`fhir.client`)
* Coroutine‑based asynchronous client (`fhir.async_client`)
* Resource CRUD helpers (create / save / get / patch / delete)
* Fluent SearchSet query builder with modifiers (`birthdate__gt`, `_sort`, `_count`)
* Lightweight `Reference` objects

> **Status:** Proof‑of‑concept — good enough for demos & unit tests. Pull requests welcome!

---
## Installation

Install luarocks Lua package manager

### On Ubuntu/Debian
sudo apt install luarocks

### On macOS with Homebrew
brew install luarocks


```bash
# install locally
luarocks make --local fhir-skeleton-0.2.0-1.rockspec

# or, once published to LuaRocks
luarocks install fhir-skeleton
```

Dependencies: **Lua 5.3+**, `lua‑cjson`, `lua‑socket` (default HTTP backend). Swap in a different backend by replacing `fhir.util.http`.

---
## Quick Start (Sync)

```lua
local fhir   = require("fhir")
local Client = fhir.client

local client = Client.new{ baseUrl = "https://hapi.fhir.org/baseR4" }

-- create a new Patient
local pat = fhir.resource:new("Patient", {
  active = true,
  name   = { { given = {"John"}, family = "Doe" } },
})
client:create(pat)
print("Patient ID:", pat.id)

-- fetch
local p2 = client:get("Patient", pat.id)
print(p2.name[1].family)
```

---
## Quick Start (Async)

```lua
local AsyncClient = require("fhir.async_client")
local Resource    = require("fhir.resource")

local client = AsyncClient.new{ baseUrl = "https://hapi.fhir.org/baseR4" }

local co = client:create(Resource:new("Patient", { active=true }))
local patient = co()      -- resume coroutine until completion
print("created", patient.id)
```

Each CRUD/search call returns a **thunk** — resume it to continue.  Integrate
with event loops (Luvit, Copas, Lua‑http) by yielding/resuming within your own
scheduler.

---
## Fluent Search Examples

```lua
local bundle = client:resources("Patient")
                :search{ name = "Smith", birthdate__gt = "1970" }
                :limit(5)
                :sort("name")
                :fetch()

for _,e in ipairs(bundle.entry or {}) do
  print(e.resource.id, e.resource.name[1].text)
end
```

`SearchSet:first()` fetches only one resource; `limit(n)` maps to `_count=n`.

---
## Working with References

```lua
local ref   = client:reference("Observation", "abc123")
local obs   = ref:to_resource()  -- GET /Observation/abc123
print(obs.status)
ref:delete()                     -- DELETE /Observation/abc123
```

---
## Error Handling

Every HTTP 4xx/5xx raises a Lua error table:

```lua
local ok, err = pcall(client.get, client, "Patient", "nope")
if not ok then
  print(err.status)    -- HTTP status code
  print(err.body)      -- OperationOutcome (if any)
end
```

---
## Replacing the HTTP Backend

`fhir.util.http` is a minimal LuaSocket wrapper.  To run fully non‑blocking
under **lua‑http** or **Luvit**, implement a drop‑in object exposing:

```lua
:get(path)           -> data, headers
:post(path, body)    -> data, headers
-- etc for put/patch/delete
```

and pass it during client construction:

```lua
local http_async = require("my_http_async")
local client = Client.new{ baseUrl = url, http_options = {}, headers = {}, http = http_async }
```

---
### License
Apache 2.0