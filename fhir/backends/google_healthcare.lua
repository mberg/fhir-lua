local json = require("cjson.safe")
local http = require("socket.http")
local ltn12 = require("ltn12")

local GoogleHealthcare = {}
GoogleHealthcare.__index = GoogleHealthcare

-- Configuration constants
local GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
local GOOGLE_HEALTHCARE_BASE = "https://healthcare.googleapis.com/v1"
local DEFAULT_SCOPES = {"https://www.googleapis.com/auth/cloud-platform"}

function GoogleHealthcare.new(config)
  assert(config, "Configuration required")
  assert(config.project_id, "project_id required")
  assert(config.location, "location required") 
  assert(config.dataset_id, "dataset_id required")
  assert(config.fhir_store_id, "fhir_store_id required")
  
  local self = setmetatable({}, GoogleHealthcare)
  self.project_id = config.project_id
  self.location = config.location
  self.dataset_id = config.dataset_id
  self.fhir_store_id = config.fhir_store_id
  self.service_account_key = config.service_account_key
  self.access_token = nil
  self.token_expires_at = 0
  
  -- Build base FHIR store path
  self.fhir_store_path = string.format(
    "%s/projects/%s/locations/%s/datasets/%s/fhirStores/%s",
    GOOGLE_HEALTHCARE_BASE, self.project_id, self.location, 
    self.dataset_id, self.fhir_store_id
  )
  
  return self
end

-- Authentication helper functions
local function base64_encode(data)
  local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  return (data:gsub('.', function(x)
    local r, b = '', x:byte()
    for i = 8, 1, -1 do r = r .. (b % 2^i - b % 2^(i-1) > 0 and '1' or '0') end
    return r
  end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if #x < 6 then return '' end
    local c = 0
    for i = 1, 6 do c = c + (x:sub(i,i) == '1' and 2^(6-i) or 0) end
    return b64chars:sub(c+1,c+1)
  end) .. ({'', '==', '='})[#data%3+1]
end

local function url_safe_base64_encode(data)
  return base64_encode(data):gsub('+', '-'):gsub('/', '_'):gsub('=', '')
end

local function create_jwt_header()
  return url_safe_base64_encode(json.encode({
    alg = "RS256",
    typ = "JWT"
  }))
end

local function create_jwt_claims(service_account, scopes)
  local now = os.time()
  return url_safe_base64_encode(json.encode({
    iss = service_account.client_email,
    scope = table.concat(scopes or DEFAULT_SCOPES, " "),
    aud = GOOGLE_TOKEN_URL,
    exp = now + 3600, -- 1 hour
    iat = now
  }))
end

-- Simple RSA signature placeholder - in production, use a proper crypto library
local function sign_jwt(unsigned_jwt, private_key)
  -- WARNING: This is a placeholder. In production, you need proper RSA-SHA256 signing
  -- Consider using lua-resty-jwt, luacrypto, or similar libraries
  error("JWT signing not implemented. Please implement RSA-SHA256 signing or use gcloud CLI for tokens.")
end

function GoogleHealthcare:get_access_token_from_gcloud()
  -- Try to get token from gcloud CLI
  local handle = io.popen("gcloud auth application-default print-access-token 2>/dev/null")
  if handle then
    local token = handle:read("*a")
    handle:close()
    if token and #token > 0 then
      return token:gsub("%s+", "") -- trim whitespace
    end
  end
  return nil
end

function GoogleHealthcare:authenticate()
  -- Check if current token is still valid
  if self.access_token and os.time() < self.token_expires_at - 60 then
    return self.access_token
  end
  
  -- Try gcloud CLI first (for development)
  local token = self:get_access_token_from_gcloud()
  if token then
    self.access_token = token
    self.token_expires_at = os.time() + 3600 -- Assume 1 hour validity
    return token
  end
  
  -- For service account key authentication, you would implement JWT signing here
  if self.service_account_key then
    error("Service account key authentication requires JWT signing implementation. " ..
          "Please set up gcloud CLI or implement proper JWT signing.")
  end
  
  error("No authentication method available. Please run 'gcloud auth application-default login' " ..
        "or provide a service account key with proper JWT signing implementation.")
end

local function make_request(method, url, headers, body)
  local resp = {}
  local payload = body and json.encode(body)
  
  local req_headers = {
    ["content-type"] = "application/fhir+json",
    ["accept"] = "application/fhir+json"
  }
  
  -- Merge provided headers
  if headers then
    for k, v in pairs(headers) do
      req_headers[k:lower()] = v
    end
  end
  
  local _, code, response_headers = http.request{
    method = method,
    url = url,
    headers = req_headers,
    source = payload and ltn12.source.string(payload) or nil,
    sink = ltn12.sink.table(resp),
  }
  
  local raw = table.concat(resp)
  local data = (#raw > 0) and json.decode(raw) or {}
  
  if code >= 400 then
    error({
      status = code,
      body = data,
      headers = response_headers,
      message = "Google Healthcare API error"
    })
  end
  
  return data, response_headers
end

function GoogleHealthcare:_req(method, path, body)
  local token = self:authenticate()
  local url = self.fhir_store_path .. "/fhir/R4" .. path
  
  local headers = {
    ["authorization"] = "Bearer " .. token
  }
  
  return make_request(method, url, headers, body)
end

-- Standard HTTP methods
function GoogleHealthcare:get(path)
  return self:_req("GET", path)
end

function GoogleHealthcare:post(path, body)
  return self:_req("POST", path, body)
end

function GoogleHealthcare:put(path, body)
  return self:_req("PUT", path, body)
end

function GoogleHealthcare:patch(path, body)
  return self:_req("PATCH", path, body)
end

function GoogleHealthcare:delete(path)
  return self:_req("DELETE", path)
end

-- Google Healthcare specific methods
function GoogleHealthcare:search_resources(resource_type, params)
  local query_string = ""
  if params then
    local query_parts = {}
    for k, v in pairs(params) do
      table.insert(query_parts, k .. "=" .. tostring(v))
    end
    if #query_parts > 0 then
      query_string = "?" .. table.concat(query_parts, "&")
    end
  end
  
  return self:get("/" .. resource_type .. query_string)
end

function GoogleHealthcare:get_resource(resource_type, resource_id)
  return self:get("/" .. resource_type .. "/" .. resource_id)
end

function GoogleHealthcare:create_resource(resource_type, resource_data)
  return self:post("/" .. resource_type, resource_data)
end

function GoogleHealthcare:update_resource(resource_type, resource_id, resource_data)
  return self:put("/" .. resource_type .. "/" .. resource_id, resource_data)
end

function GoogleHealthcare:delete_resource(resource_type, resource_id)
  return self:delete("/" .. resource_type .. "/" .. resource_id)
end

return GoogleHealthcare 