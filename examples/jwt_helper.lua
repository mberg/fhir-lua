#!/usr/bin/env lua

--[[
JWT Helper for Google Service Account Authentication

This helper shows how to implement proper JWT signing for production use
with Google service account keys. This is what you would need to implement
to use service account keys directly without gcloud CLI.

IMPORTANT: This is educational code showing the structure needed.
For production use, you should use a proper cryptographic library like:
- lua-resty-jwt
- luacrypto  
- openssl bindings for Lua
- Or Google Cloud client libraries

The current FHIR-Lua implementation falls back to gcloud CLI authentication
because implementing crypto from scratch is not recommended for production.
]]

local json = require("cjson.safe")

local JWTHelper = {}

-- JWT Header for Google service accounts
function JWTHelper.create_header()
  return {
    alg = "RS256",
    typ = "JWT"
  }
end

-- JWT Claims for Google service account
function JWTHelper.create_claims(service_account, scopes, target_audience)
  local now = os.time()
  scopes = scopes or {"https://www.googleapis.com/auth/cloud-platform"}
  target_audience = target_audience or "https://oauth2.googleapis.com/token"
  
  return {
    iss = service_account.client_email,    -- Issuer: service account email
    scope = table.concat(scopes, " "),     -- Requested scopes
    aud = target_audience,                 -- Audience: Google token endpoint
    exp = now + 3600,                      -- Expires: 1 hour from now
    iat = now                              -- Issued at: now
  }
end

-- Base64 URL-safe encoding (without padding)
function JWTHelper.base64url_encode(data)
  -- This is a simplified version - use a proper base64 library in production
  local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'
  
  -- Convert to base64 first (simplified implementation)
  local result = ""
  local padding = 3 - ((#data - 1) % 3)
  
  for i = 1, #data, 3 do
    local c1, c2, c3 = data:byte(i), data:byte(i+1) or 0, data:byte(i+2) or 0
    local bitmap = (c1 << 16) + (c2 << 8) + c3
    
    result = result .. b64chars:sub((bitmap >> 18) + 1, (bitmap >> 18) + 1)
    result = result .. b64chars:sub(((bitmap >> 12) & 63) + 1, ((bitmap >> 12) & 63) + 1)
    
    if i + 1 <= #data then
      result = result .. b64chars:sub(((bitmap >> 6) & 63) + 1, ((bitmap >> 6) & 63) + 1)
    end
    if i + 2 <= #data then
      result = result .. b64chars:sub((bitmap & 63) + 1, (bitmap & 63) + 1)
    end
  end
  
  return result
end

-- Create unsigned JWT
function JWTHelper.create_unsigned_jwt(service_account, scopes, target_audience)
  local header = JWTHelper.create_header()
  local claims = JWTHelper.create_claims(service_account, scopes, target_audience)
  
  local header_json = json.encode(header)
  local claims_json = json.encode(claims)
  
  local header_b64 = JWTHelper.base64url_encode(header_json)
  local claims_b64 = JWTHelper.base64url_encode(claims_json)
  
  return header_b64 .. "." .. claims_b64
end

-- RSA-SHA256 signature (PLACEHOLDER - IMPLEMENT WITH CRYPTO LIBRARY)
function JWTHelper.sign_rsa_sha256(unsigned_jwt, private_key_pem)
  --[[
  This is where you would implement RSA-SHA256 signing.
  
  Steps needed:
  1. Parse the PEM private key
  2. Create SHA256 hash of the unsigned JWT
  3. Sign the hash with RSA private key
  4. Base64url encode the signature
  
  Example with lua-resty-jwt:
  
  local resty_jwt = require("resty.jwt")
  local jwt_token = resty_jwt:sign(
    "secret_key",
    {
      header = header,
      payload = claims
    }
  )
  
  Example with luacrypto:
  
  local crypto = require("crypto")
  local key = crypto.pkey.from_pem(private_key_pem, true)  -- true for private key
  local hash = crypto.digest("sha256", unsigned_jwt)
  local signature = key:sign(hash)
  local signature_b64 = JWTHelper.base64url_encode(signature)
  ]]
  
  error("RSA-SHA256 signing not implemented. Please use a cryptographic library.")
end

-- Complete JWT creation (would be used in production)
function JWTHelper.create_signed_jwt(service_account, scopes, target_audience)
  local unsigned_jwt = JWTHelper.create_unsigned_jwt(service_account, scopes, target_audience)
  local signature = JWTHelper.sign_rsa_sha256(unsigned_jwt, service_account.private_key)
  
  return unsigned_jwt .. "." .. signature
end

-- Exchange JWT for access token
function JWTHelper.exchange_jwt_for_token(signed_jwt)
  --[[
  This would make an HTTP POST request to:
  https://oauth2.googleapis.com/token
  
  With form data:
  grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer
  assertion=<signed_jwt>
  
  Returns:
  {
    "access_token": "ya29.AHES6ZR...",
    "token_type": "Bearer", 
    "expires_in": 3600
  }
  ]]
  
  local http = require("socket.http")
  local ltn12 = require("ltn12")
  
  local form_data = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=" .. signed_jwt
  
  local resp = {}
  local _, code, headers = http.request{
    method = "POST",
    url = "https://oauth2.googleapis.com/token",
    headers = {
      ["content-type"] = "application/x-www-form-urlencoded",
      ["content-length"] = #form_data
    },
    source = ltn12.source.string(form_data),
    sink = ltn12.sink.table(resp)
  }
  
  local response_body = table.concat(resp)
  local response_data = json.decode(response_body)
  
  if code >= 400 then
    error("Token exchange failed: " .. (response_data.error_description or response_body))
  end
  
  return response_data.access_token, response_data.expires_in
end

-- Example usage function
function JWTHelper.example_usage()
  print("=== JWT Helper Example ===")
  print("\n1. Load service account key:")
  print([[
  local file = io.open("service-account-key.json", "r")
  local content = file:read("*a")
  file:close()
  local service_account = json.decode(content)
  ]])
  
  print("\n2. Create unsigned JWT:")
  print([[
  local unsigned_jwt = JWTHelper.create_unsigned_jwt(
    service_account,
    {"https://www.googleapis.com/auth/cloud-platform"}
  )
  ]])
  
  print("\n3. Sign JWT (requires crypto library):")
  print([[
  -- With lua-resty-jwt:
  local resty_jwt = require("resty.jwt")
  local signed_jwt = resty_jwt:sign("secret", {
    header = {alg = "RS256", typ = "JWT"},
    payload = claims
  })
  
  -- With luacrypto:
  local crypto = require("crypto") 
  local key = crypto.pkey.from_pem(service_account.private_key, true)
  local signature = key:sign(crypto.digest("sha256", unsigned_jwt))
  ]])
  
  print("\n4. Exchange for access token:")
  print([[
  local access_token, expires_in = JWTHelper.exchange_jwt_for_token(signed_jwt)
  ]])
  
  print("\n5. Use token in HTTP requests:")
  print([[
  headers = {
    ["Authorization"] = "Bearer " .. access_token,
    ["Content-Type"] = "application/fhir+json"
  }
  ]])
  
  print("\nFor production implementation, consider:")
  print("- lua-resty-jwt for JWT handling")
  print("- luacrypto for RSA operations") 
  print("- Google Cloud client libraries")
  print("- Token caching and refresh logic")
end

-- Show example if run directly
if arg and arg[0] and arg[0]:match("jwt_helper%.lua$") then
  JWTHelper.example_usage()
end

return JWTHelper 