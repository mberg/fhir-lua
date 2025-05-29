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
sudo apt install luarocks

### On macOS with Homebrew
brew install luarocks

```bash
# Install dependencies (including lua-dotenv for .env support)
luarocks install lua-cjson --local
luarocks install luasocket --local
luarocks install luasec --local
luarocks install lua-dotenv --local

# Install fhir-lua locally
luarocks make --local fhir-skeleton-0.2.0-1.rockspec
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
## Examples

- **[examples/google_healthcare_example.lua](examples/google_healthcare_example.lua)** - Complete Google Healthcare API demo
- **[examples/create_patient_with_key.lua](examples/create_patient_with_key.lua)** - Create patient using service account key file
- **[examples/jwt_helper.lua](examples/jwt_helper.lua)** - JWT signing helper for production authentication
- **[CONNECT.md](CONNECT.md)** - Google Healthcare API setup guide

### Using Service Account Keys and .env file

To create a patient using Google Healthcare API, ensure your `.env` file is configured as shown above.

If you have a service account key JSON file, you can specify its path in the `.env` file using `GOOGLE_SERVICE_ACCOUNT_KEY_PATH` or pass it as a command-line argument to the script.

```bash
# Ensure .env file is present in the project root
# Example .env contents:
# GOOGLE_PROJECT_ID="ada-health-459902"
# GOOGLE_LOCATION="us-central1"
# GOOGLE_DATASET_ID="demo-fhir"
# GOOGLE_FHIR_STORE_ID="my-dataset"
# GOOGLE_SERVICE_ACCOUNT_KEY_PATH="../healthcare-api/ada-health-459902-205e36f7d1b8.json"

# Run the script (key path from .env or as argument)
lua examples/create_patient_with_key.lua
# OR (if GOOGLE_SERVICE_ACCOUNT_KEY_PATH is not in .env):
lua examples/create_patient_with_key.lua ../healthcare-api/your-key.json
```

The script will:
1. Load configuration from `.env` (GOOGLE_PROJECT_ID, etc.).
2. Optionally load your service account key if `GOOGLE_SERVICE_ACCOUNT_KEY_PATH` is set or a path is provided as an argument.
3. Set up authentication (primarily via gcloud CLI for this example, as direct JWT signing is a separate implementation).
4. Create a male patient named Mary Jane, age 47.
5. Verify the patient was created successfully.

**Note:** For production use with service account keys directly (without gcloud CLI), implement proper JWT signing using libraries like `lua-resty-jwt` or `luacrypto`. See `examples/jwt_helper.lua` for guidance. The `fhir.client` will pass the `service_account_key_path` (if available from `.env` or opts) to the Google backend, which can be used by a full JWT implementation.

You might need this installed too

brew install google-cloud-sdk

---
### License
Apache 2.0