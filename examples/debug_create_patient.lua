#!/usr/bin/env lua

--[[
Debug version to see what URL is being constructed
]]

local fhir = require("fhir")
local json = require("cjson.safe")

-- Configuration from environment
local project_id = "ada-health-459902"
local location = "us-central1"
local dataset_id = "demo-fhir"
local fhir_store_id = "my-dataset"

print("=== Debug: URL Construction ===")
print("Configuration:")
print("  Project ID:", project_id)
print("  Location:", location)
print("  Dataset ID:", dataset_id)  
print("  FHIR Store ID:", fhir_store_id)

-- Create client
local client = fhir.client.new{
  backend = "google_healthcare",
  google_config = {
    project_id = project_id,
    location = location,
    dataset_id = dataset_id,
    fhir_store_id = fhir_store_id
  }
}

print("\nClient created successfully")
print("  Base URL:", client.baseUrl)

-- Let's try to examine the HTTP backend
print("\nHTTP Backend Details:")
print("  FHIR Store Path:", client.http.fhir_store_path)

-- Calculate what the full URL should be for Patient creation
local expected_url = client.http.fhir_store_path .. "/fhir/R4/Patient"
print("  Expected POST URL:", expected_url)

-- Try to get an access token
print("\nAuthentication Test:")
local ok, token = pcall(function() return client.http:authenticate() end)
if ok then
  print("  ✅ Authentication successful")
  print("  Token (first 20 chars):", token:sub(1, 20) .. "...")
else
  print("  ❌ Authentication failed:", token)
  os.exit(1)
end

-- Now let's try a simple test request to see if the FHIR store is accessible
print("\nTesting FHIR Store Access:")

-- Try to get the CapabilityStatement (metadata endpoint)
local metadata_url = expected_url:gsub("/Patient$", "/metadata")
print("  Testing metadata endpoint:", metadata_url)

local ok_metadata, result = pcall(function()
  return client.http:get("/metadata")
end)

if ok_metadata then
  print("  ✅ FHIR store accessible!")
  print("  Implementation:", result.software and result.software.name or "Unknown")
  print("  FHIR Version:", result.fhirVersion or "Unknown")
else
  print("  ❌ FHIR store access failed")
  
  -- Check if it's a 404 vs other error
  if type(result) == "table" then
    print("  HTTP Status:", result.status or "Unknown")
    print("  Error Body:")
    if result.body then
      print("    ", json.encode(result.body))
    else
      print("    No body")
    end
    if result.message then
      print("  Message:", result.message)
    end
  else
    print("  Error:", result)
  end
end

-- Try a different approach - test a simple GET request to list patients
print("\nTesting Patient List:")
local ok_list, list_result = pcall(function()
  return client.http:get("/Patient")
end)

if ok_list then
  print("  ✅ Patient list accessible!")
  print("  Resource type:", list_result.resourceType)
  print("  Total entries:", list_result.total or 0)
else
  print("  ❌ Patient list failed")
  if type(list_result) == "table" then
    print("  HTTP Status:", list_result.status or "Unknown")
    print("  Error Body:")
    if list_result.body then
      print("    ", json.encode(list_result.body))
    else
      print("    No body")
    end
  else
    print("  Error:", list_result)
  end
end

print("\n=== Manual FHIR Store Check ===")
print("Run this command to verify your FHIR store exists:")
print("gcloud healthcare fhir-stores describe my-dataset \\")
print("  --dataset=demo-fhir \\") 
print("  --location=us-central1 \\")
print("  --project=ada-health-459902")

print("\nIf that fails, create the FHIR store with:")
print("gcloud healthcare fhir-stores create my-dataset \\")
print("  --dataset=demo-fhir \\")
print("  --location=us-central1 \\") 
print("  --project=ada-health-459902 \\")
print("  --version=R4") 