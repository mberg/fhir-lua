--[[
FHIR Client Module

This module provides the main Client class for interacting with FHIR servers.
It supports multiple backends including standard HTTP and Google Healthcare API,
and provides a complete interface for CRUD operations, search functionality,
and resource reference handling.

The Client automatically loads environment configuration via dotenv and supports
both synchronous and asynchronous operation modes. It serves as the foundation
for all FHIR operations in this library.

Features:
- Multiple backend support (HTTP, Google Healthcare)
- Environment variable configuration via dotenv
- Complete CRUD operations (Create, Read, Update, Delete)
- Search query building with SearchSet
- Resource reference handling
- Extensible architecture for custom backends
]]--

local Http        = require("fhir.util.http")
local Resource    = require("fhir.resource")
local SearchSet   = require("fhir.searchset")
local Reference   = require("fhir.reference")

-- Load dotenv configuration when the module is first loaded
if not _G.__fhir_dotenv_loaded then
  local success, dotenv = pcall(require, "lua-dotenv")
  if success and dotenv and type(dotenv.load_dotenv) == "function" then
    
    --[[
    Check if a file exists and is readable
    
    @param path (string): File path to check
    @return (boolean): True if file exists and is readable, false otherwise
    ]]--
    local function file_exists(path)
      local file = io.open(path, "r")
      if file then
        file:close()
        return true
      end
      return false
    end
    
    --[[
    Try to find and load .env file from multiple locations
    
    @return (string|nil): Path where .env file was loaded from, or nil if not found
    ]]--
    local function load_env_file()
      local search_paths = {
        "./.env",                                    -- Current working directory
        "../.env",                                   -- Parent directory
        "../../.env",                                -- Grandparent directory  
        "../../../.env",                             -- Great-grandparent directory
        os.getenv("HOME") .. "/.config/.env"         -- Default lua-dotenv location
      }
      
      for _, env_path in ipairs(search_paths) do
        if env_path and file_exists(env_path) then
          local load_ok, load_err = pcall(dotenv.load_dotenv, env_path)
          if load_ok then
            return env_path
          end
        end
      end
      
      -- If no .env file found, try loading from default location without file check
      -- This allows lua-dotenv to use its default ~/.config/.env if it exists
      local default_load_ok = pcall(dotenv.load_dotenv)
      if default_load_ok then
        return "~/.config/.env (default)"
      end
      
      return nil
    end
    
    local loaded_path = load_env_file()
    if loaded_path then
      -- Store dotenv module globally so we can use it later
      _G.__fhir_dotenv_module = dotenv
      _G.__fhir_dotenv_loaded_from = loaded_path
    end
    _G.__fhir_dotenv_loaded = true
  end
end

local Client = {}
Client.__index = Client

--[[
Creates a new FHIR Client instance with the specified configuration

@param opts (table): Configuration options including:
  - mode (string, optional): Operation mode ("sync" or "async", default: "sync")
  - backend (string, optional): Backend type ("google_healthcare" or default HTTP)
  - baseUrl (string): Base URL for HTTP backend (required for HTTP backend)
  - headers (table, optional): Additional HTTP headers for HTTP backend
  - http_options (table, optional): Additional HTTP client options
  - google_config (table, optional): Google Healthcare API configuration
@return (Client): A new Client instance configured for the specified backend
]]--
function Client.new(opts)
  assert(opts, "Configuration options required")
  
  local self = setmetatable({}, Client)
  self.mode = opts.mode or "sync"
  
  -- Backend selection
  if opts.backend == "google_healthcare" then
    local GoogleHealthcare = require("fhir.backends.google_healthcare")
    -- Initialize google_config. If opts.google_config is nil, this creates an empty table.
    local google_config = opts.google_config or {}

    --[[
    Helper function to get environment variables, trying dotenv first, then os.getenv
    
    @param key (string): Environment variable name
    @return (string|nil): Environment variable value or nil if not found
    ]]--
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

--[[
Helper function to build resource paths

@param rt (string): Resource type
@param id (string, optional): Resource ID
@return (string): Formatted resource path
]]--
local function path(rt, id)
  return "/" .. rt .. (id and ("/" .. id) or "")
end

-- CRUD Operations --------------------------------------------------------

--[[
Creates a new resource on the FHIR server

@param resource (Resource): The resource instance to create
@return (Resource, table): The updated resource with server-assigned ID and the server response
]]--
function Client:create(resource)
  local data = resource:serialize()
  local body = self.http:post(path(resource.resourceType), data)
  if body.id then
    resource.id = body.id
  end
  return resource, body
end

--[[
Saves (updates) an existing resource on the FHIR server

@param resource (Resource): The resource instance to save (must have an ID)
@return (Resource, table): The updated resource and the server response
]]--
function Client:save(resource)
  assert(resource.id, "resource.id required for save")
  local body = self.http:put(path(resource.resourceType, resource.id), resource:serialize())
  return resource, body
end

--[[
Retrieves a resource from the FHIR server by type and ID

@param rt (string): Resource type
@param id (string): Resource ID
@return (Resource): The retrieved resource instance
]]--
function Client:get(rt, id)
  local data = self.http:get(path(rt, id))
  return Resource:new(rt, data)
end

--[[
Applies a patch to a resource on the FHIR server

@param rt (string): Resource type
@param id (string): Resource ID
@param patchBody (table): The patch operations to apply
@return (any): The server response
]]--
function Client:patch(rt, id, patchBody)
  return self.http:patch(path(rt, id), patchBody)
end

--[[
Deletes a resource from the FHIR server

@param rt (string): Resource type
@param id (string): Resource ID
@return (any): The server response
]]--
function Client:delete(rt, id)
  return self.http:delete(path(rt, id))
end

-- Search Builder ---------------------------------------------------------

--[[
Creates a SearchSet for building search queries against a specific resource type

@param rt (string): The resource type to search for
@return (SearchSet): A new SearchSet instance for building queries
]]--
function Client:resources(rt)
  return SearchSet.new(self, rt)
end

-- Reference Helper -------------------------------------------------------

--[[
Creates a Reference instance pointing to a specific resource

@param rt (string): Resource type
@param id (string): Resource ID
@return (Reference): A new Reference instance for the specified resource
]]--
function Client:reference(rt, id)
  return Reference.new(self, rt, id)
end

-- Backend-Specific Helper Methods ---------------------------------------

--[[
Checks if this client is configured for Google Healthcare API

@return (boolean): True if using Google Healthcare backend, false otherwise
]]--
function Client:is_google_healthcare()
  return self.baseUrl and self.baseUrl:match("^google_healthcare://")
end

return Client 