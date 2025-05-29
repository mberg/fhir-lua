# FHIR‑Lua

Early **Lua port** of the popular [fhir‑py](https://github.com/beda‑software/fhir‑py) client.
Supports:

* Synchronous client (`fhir.client`)
* Coroutine‑based asynchronous client (`fhir.async_client`)
* Resource CRUD helpers (create / save / get / patch / delete)
* Fluent SearchSet query builder with modifiers (`birthdate__gt`, `_sort`, `_count`)
* Lightweight `Reference` objects
* **Google Healthcare API backend** for production FHIR operations

> **Status:** Proof‑of‑concept — good enough for demos & unit tests. Pull requests welcome!

---
## Installation

Install luarocks Lua package manager

### On Ubuntu/Debian
```bash
sudo apt install luarocks
```
### On macOS with Homebrew
```bash
brew install luarocks
```

```bash
# Install dependencies (including lua-dotenv for .env support)
luarocks install lua-cjson --local
luarocks install luasocket --local
luarocks install luasec --local
luarocks install lua-dotenv --local

# Install fhir-lua locally
luarocks make fhir-lua-0.2.0-1.rockspec
```

Dependencies: **Lua 5.1+**, `lua-cjson`, `luasocket`, `luasec`, `lua-dotenv`. Swap in a different backend by replacing `fhir.util.http`.

---
## Quick Start (Sync)

### Standard FHIR Server

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

### Google Healthcare API

For Google Healthcare API, create a `.env` file in your project root:

```env
GOOGLE_PROJECT_ID="your-gcp-project"
GOOGLE_LOCATION="us-central1" 
GOOGLE_DATASET_ID="your-dataset"
GOOGLE_FHIR_STORE_ID="your-fhir-store"
# Optional: Path to your service account key JSON file
# GOOGLE_SERVICE_ACCOUNT_KEY_PATH="/path/to/your-service-account-key.json"
```

Then, you can initialize the client simply:

```lua
local fhir = require("fhir")

-- Configure for Google Healthcare API (reads from .env)
local client = fhir.client.new{
  backend = "google_healthcare"
  -- google_config is now optional and will be picked up from .env
  -- You can still override here: 
  -- google_config = { project_id = "override-project" }
}

-- Same FHIR operations work with Google Healthcare
local patient = fhir.resource:new("Patient", { active = true })
client:create(patient)
print("Created patient:", patient.id)
```

See **[CONNECT.md](CONNECT.md)** for detailed Google Healthcare API setup.

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
## Backend Support

FHIR-Lua supports multiple backends:

### Standard HTTP FHIR Servers
```lua
local client = fhir.client.new{
  baseUrl = "https://hapi.fhir.org/baseR4"
}
```

### Google Healthcare API
```lua
local client = fhir.client.new{
  backend = "google_healthcare",
  google_config = {
    project_id = "your-project",
    location = "us-central1",
    dataset_id = "your-dataset", 
    fhir_store_id = "your-store"
  }
}

You might need this installed too

brew install google-cloud-sdk

-- Google-specific methods also available
local results = client:google_search("Patient", { family = "Smith" })
```

### Adding New Backends

To add support for new FHIR backends:

1. Create a new module in `fhir/backends/your_backend.lua`
2. Implement the HTTP interface: `get`, `post`, `put`, `patch`, `delete`
3. Update `fhir/client.lua` to recognize your backend
4. See `fhir/backends/google_healthcare.lua` as an example


---
## Examples

- **[examples/create_patient.lua](examples/create_patient.lua)** - Simple patient creation using Google Healthcare API
- **[examples/create_patient_async.lua](examples/create_patient_async.lua)** - Async patient creation with coroutines
- **[examples/find_patient.lua](examples/find_patient.lua)** - Search for patients by ID or name with CLI parameters
- **[examples/record_vaccine.lua](examples/record_vaccine.lua)** - Record immunizations/vaccines for patients
- **[examples/jwt_helper.lua](examples/jwt_helper.lua)** - JWT signing helper for production authentication
- **[CONNECT.md](CONNECT.md)** - Google Healthcare API setup guide

### Running Examples

All examples automatically load configuration from your `.env` file. To run any example:  

```bash
# Simple patient creation
lua examples/create_patient.lua

# Async patient creation  
lua examples/create_patient_async.lua

# Find patient by ID or name
lua examples/find_patient.lua f16195fd-25d0-4294-ad6f-8c1046897293
lua examples/find_patient.lua "John"

# Record a vaccine for a patient
lua examples/record_vaccine.lua
```

### Using .env Configuration

All examples support automatic `.env` file loading. Create a `.env` file in your project root:

```env
GOOGLE_PROJECT_ID="your-gcp-project"
GOOGLE_LOCATION="us-central1" 
GOOGLE_DATASET_ID="your-dataset"
GOOGLE_FHIR_STORE_ID="your-fhir-store"
# Optional: Path to your service account key JSON file
GOOGLE_SERVICE_ACCOUNT_KEY_PATH="/path/to/your-service-account-key.json"
```

The examples will automatically find and load this configuration from:
- Current directory (`./.env`)
- Parent directories (`../.env`, `../../.env`, etc.)  
- Default lua-dotenv location (`~/.config/.env`)

**Note:** For production use with service account keys directly (without gcloud CLI), implement proper JWT signing using libraries like `lua-resty-jwt` or `luacrypto`. See `examples/jwt_helper.lua` for guidance.



---
### License
Apache 2.0