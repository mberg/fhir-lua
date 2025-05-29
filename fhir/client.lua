local Http        = require("fhir.util.http")
local Resource    = require("fhir.resource")
local SearchSet   = require("fhir.searchset")
local Reference   = require("fhir.reference")

-- Load dotenv configuration when the module is first loaded
if not _G.__fhir_dotenv_loaded then
  local success, dotenv = pcall(require, "lua-dotenv")
  if success and dotenv and type(dotenv.load_dotenv) == "function" then
    -- lua-dotenv looks for .env in ~/.config/.env by default
    -- We need to specify the path to our project's .env file
    local env_file_path = "./.env"  -- Relative to current working directory
    local load_ok, load_err = pcall(dotenv.load_dotenv, env_file_path)
    if load_ok then
      -- Store dotenv module globally so we can use it later
      _G.__fhir_dotenv_module = dotenv
    end
    _G.__fhir_dotenv_loaded = true
  end
end

local Client = {}
Client.__index = Client

function Client.new(opts)
  assert(opts, "Configuration options required")
  
  local self = setmetatable({}, Client)
  self.mode = opts.mode or "sync"
  
  -- Backend selection
  if opts.backend == "google_healthcare" then
    local GoogleHealthcare = require("fhir.backends.google_healthcare")
    -- Initialize google_config. If opts.google_config is nil, this creates an empty table.
    local google_config = opts.google_config or {}

    -- Helper function to get environment variables, trying dotenv first, then os.getenv
    local function get_env_var(key)
      if _G.__fhir_dotenv_module then
        return _G.__fhir_dotenv_module.get(key) or os.getenv(key)
      else
        return os.getenv(key)
      end
    end

    -- Populate google_config from environment variables if not provided in google_config table
    google_config.project_id = google_config.project_id or get_env_var("GOOGLE_PROJECT_ID")
    google_config.location = google_config.location or get_env_var("GOOGLE_LOCATION")
    google_config.dataset_id = google_config.dataset_id or get_env_var("GOOGLE_DATASET_ID")
    google_config.fhir_store_id = google_config.fhir_store_id or get_env_var("GOOGLE_FHIR_STORE_ID")
    
    -- Service account key path can also come from env if not directly in google_config
    local key_path_from_env = get_env_var("GOOGLE_SERVICE_ACCOUNT_KEY_PATH")
    google_config.service_account_key = google_config.service_account_key or key_path_from_env

    assert(google_config.project_id, "google_config.project_id or GOOGLE_PROJECT_ID environment variable required")
    assert(google_config.location, "google_config.location or GOOGLE_LOCATION environment variable required")
    assert(google_config.dataset_id, "google_config.dataset_id or GOOGLE_DATASET_ID environment variable required")
    assert(google_config.fhir_store_id, "google_config.fhir_store_id or GOOGLE_FHIR_STORE_ID environment variable required")

    self.http = GoogleHealthcare.new(google_config)
    self.baseUrl = "google_healthcare://" .. google_config.project_id
    
    -- Extend client with Google-specific methods
    local GoogleClient = require("fhir.backends.google_client")
    GoogleClient.extend_client(self)
  else
    -- Default to standard HTTP backend
    assert(opts.baseUrl, "baseUrl required for standard HTTP backend")
    self.baseUrl = opts.baseUrl:gsub("/*$", "")
    self.headers = opts.headers or {}
    self.http = Http.new(self.baseUrl, self.headers, opts.http_options)
  end
  
  return self
end

local function path(rt, id) return "/" .. rt .. (id and ("/"..id) or "") end

-- CRUD --------------------------------------------------------
function Client:create(resource)
  local data = resource:serialize()
  local body = self.http:post(path(resource.resourceType), data)
  if body.id then resource.id = body.id end
  return resource, body
end

function Client:save(resource)
  assert(resource.id, "resource.id required for save")
  local body = self.http:put(path(resource.resourceType, resource.id), resource:serialize())
  return resource, body
end

function Client:get(rt, id)
  local data = self.http:get(path(rt, id))
  return Resource:new(rt, data)
end

function Client:patch(rt, id, patchBody)
  return self.http:patch(path(rt, id), patchBody)
end

function Client:delete(rt, id)
  return self.http:delete(path(rt, id))
end

-- Search builder ---------------------------------------------
function Client:resources(rt)  return SearchSet.new(self, rt) end

-- Reference helper -------------------------------------------
function Client:reference(rt, id) return Reference.new(self, rt, id) end

-- Backend-specific helper methods
function Client:is_google_healthcare()
  return self.baseUrl and self.baseUrl:match("^google_healthcare://")
end

return Client 