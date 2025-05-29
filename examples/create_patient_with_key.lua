#!/usr/bin/env lua

--[[
Create Patient with Google Service Account Key

This script demonstrates how to:
1. Load a Google service account key from JSON file (optional, if GOOGLE_SERVICE_ACCOUNT_KEY_PATH is set)
2. Use .env file for Google Cloud configuration (GOOGLE_PROJECT_ID, GOOGLE_LOCATION, etc.)
3. Authenticate with Google Healthcare API (via gcloud or service account key if JWT implemented)
4. Create a patient (Mary Jane, male, age 47)

Usage:
  lua examples/create_patient_with_key.lua [optional_path_to_service-account-key.json]

If service_account_key.json is not provided as an argument, the script will 
attempt to use GOOGLE_SERVICE_ACCOUNT_KEY_PATH from your .env file or environment.

Prerequisites:
- Google Cloud Healthcare API setup (see CONNECT.md)
- Service account with Healthcare API permissions (if using key file)
- FHIR dataset and store created
- .env file with GOOGLE_PROJECT_ID, GOOGLE_LOCATION, GOOGLE_DATASET_ID, GOOGLE_FHIR_STORE_ID
  (and optionally GOOGLE_SERVICE_ACCOUNT_KEY_PATH)

Note: This example primarily uses gcloud CLI for authentication as JWT signing
is not fully implemented in the core library. For production use with direct
service account key authentication, implement proper RSA-SHA256 JWT signing.
]]

local fhir_ok, fhir = pcall(require, "fhir")
if not fhir_ok then
  print("Error requiring 'fhir':", fhir) -- fhir here is the error message
  os.exit(1)
end

local json = require("cjson.safe") -- cjson is loaded by fhir.client, but require here for clarity

-- dotenv loading is now handled by the fhir.client module when it's required.

local key_file_path = arg[1] or os.getenv("GOOGLE_SERVICE_ACCOUNT_KEY_PATH")
local service_account_key_data = nil

-- Function to load and parse service account key
local function load_service_account_key(file_path)
  local file = io.open(file_path, "r")
  if not file then
    error("Cannot open service account key file: " .. file_path)
  end
  
  local content = file:read("*a")
  file:close()
  
  local key_data = json.decode(content)
  if not key_data then
    error("Invalid JSON in service account key file")
  end
  
  -- Validate required fields
  local required_fields = {"project_id", "client_email", "private_key", "type"}
  for _, field in ipairs(required_fields) do
    if not key_data[field] then
      error("Missing required field '" .. field .. "' in service account key")
    end
  end
  
  if key_data.type ~= "service_account" then
    error("Key file is not a service account key (type: " .. tostring(key_data.type) .. ")")
  end
  
  return key_data
end

-- Function to set up authentication using the key file
local function setup_authentication(key_data)
  print("Setting up authentication...")
  if key_data and key_data.client_email then
    print("Service Account Email (from key file):", key_data.client_email)
  else
    print("Service Account Key not loaded or client_email missing, relying on gcloud application-default credentials.")
  end
  
  -- Check if gcloud is available and authenticated
  local handle = io.popen("gcloud auth application-default print-access-token 2>/dev/null")
  if handle then
    local token = handle:read("*a")
    handle:close()
    if token and #token > 10 then
      print("✅ Using gcloud CLI application-default authentication")
      return true
    end
  end
  
  print("❌ No valid gcloud application-default authentication found.")
  print("Please ensure you have run:")
  print("  gcloud auth application-default login")
  print("OR, if using a service account key for gcloud activation (less common for app-default):")
  if key_file_path then
    print("  gcloud auth activate-service-account --key-file=" .. key_file_path)
    print("  (And then potentially 'gcloud auth application-default login' using that activated account)")
  end
  print("The library will attempt to use the service account key directly if JWT signing is implemented in the future.")
  
  return false -- Return false if gcloud token not found, but client might still work if key signing is added later.
end

-- Main script
print("=== Creating Patient with Service Account Key (via .env or CLI arg) ===\n")

if key_file_path then
  print("1. Loading service account key from: " .. key_file_path .. "...")
  local ok_key_load, loaded_key_data = pcall(load_service_account_key, key_file_path)
  if ok_key_load then
    service_account_key_data = loaded_key_data
    print("✅ Service account key loaded successfully")
    print("   Project (from key):", service_account_key_data.project_id)
    print("   Email (from key):", service_account_key_data.client_email)
  else
    print("⚠️ Warning: Could not load service account key from " .. key_file_path .. ":", loaded_key_data)
    print("   Will rely on gcloud application-default credentials or .env for project ID.")
  end
else
  print("1. Service account key file not specified via argument or GOOGLE_SERVICE_ACCOUNT_KEY_PATH.")
  print("   Relying on gcloud application-default credentials and .env for configuration.")
end

-- Setup authentication (primarily checks gcloud for this example)
print("\n2. Setting up/verifying authentication...")
if not setup_authentication(service_account_key_data) then
  -- Don't exit immediately, client.new will handle missing auth if direct key signing isn't available
  print("⚠️ gcloud application-default token not found. The script might fail if direct key signing is required and not implemented.")
end

-- Client configuration will now be primarily picked up by fhir.client.new from .env
print("\n3. FHIR Client Configuration (from .env or defaults):")
local client_config_opts = {
  backend = "google_healthcare"
  -- google_config will be auto-populated by fhir.client.new from .env or passed opts
}

-- If a service account key was loaded, pass its path (for future JWT signing use)
if service_account_key_data and key_file_path then
  client_config_opts.google_config = client_config_opts.google_config or {}
  client_config_opts.google_config.service_account_key_path = key_file_path
  print("   Service account key path will be passed to client (for potential future JWT use):", key_file_path)
end

-- Create FHIR client
print("\n4. Creating FHIR client...")

local ok_client_new, client = pcall(fhir.client.new, client_config_opts)

if not ok_client_new then
  print("❌ Error creating FHIR client:", client) -- client here is the error message
  print("Ensure .env file has GOOGLE_PROJECT_ID, GOOGLE_LOCATION, GOOGLE_DATASET_ID, GOOGLE_FHIR_STORE_ID")
  os.exit(1)
end

print("✅ FHIR client created")
print("   Connected to Google Cloud Project:", client.http.project_id) -- Accessing resolved config
print("   FHIR Store Path:", client.http.fhir_store_path)

-- Create Mary Jane patient (as in previous successful run)
print("\n5. Creating patient: Mary Jane...")

-- Calculate birth date for 47-year-old
local current_year = tonumber(os.date("%Y"))
local birth_year = current_year - 47
local birth_date = string.format("%d-01-15", birth_year)  -- Born January 15th

local patient_resource_data = {
  resourceType = "Patient", -- Ensure resourceType is present
  active = true,
  name = {
    {
      use = "official",
      family = "Jordan",
      given = {"Michael"}
    }
  },
  gender = "male", -- Keeping as male to match previous successful test for John Doe
  birthDate = birth_date,
  telecom = {
    {
      system = "email",
      value = "mary.jane@example.com",
      use = "home"
    }
  },
  address = {
    {
      use = "home",
      type = "physical",
      line = {"456 Oak Avenue"},
      city = "Anytown",
      state = "CA",
      postalCode = "12345",
      country = "US"
    }
  }
}

local patient = fhir.resource:new("Patient", patient_resource_data)

-- Attempt to create the patient
local ok_create, result = pcall(function()
  return client:create(patient)
end)

if ok_create then
  local created_patient_resource = result -- This is the resource object itself
  print("✅ Patient created successfully!")
  print("   Patient ID:", created_patient_resource.id)
  print("   Name:", created_patient_resource.name[1].given[1], created_patient_resource.name[1].family)
  print("   Gender:", created_patient_resource.gender)
  print("   Birth Date:", created_patient_resource.birthDate, "(Age: 47)")
  
  -- Constructing the full resource URL for display
  local display_base_url = string.format("https://healthcare.googleapis.com/v1/projects/%s/locations/%s/datasets/%s/fhirStores/%s/fhir", 
                                   client.http.project_id, client.http.location, client.http.dataset_id, client.http.fhir_store_id)
  print("   Resource URL:", display_base_url .. "/Patient/" .. created_patient_resource.id)
  
  -- Verify by reading the patient back
  print("\n6. Verifying patient creation...")
  local ok_verify, retrieved_patient = pcall(function() 
    return client:get("Patient", created_patient_resource.id)
  end)
  
  if ok_verify then
    print("✅ Patient verification successful")
    print("   Retrieved name:", retrieved_patient.name[1].given[1], retrieved_patient.name[1].family)
  else
    print("❌ Error verifying patient:", retrieved_patient)
  end
else
  print("❌ Error creating patient:", result)
  print("\nPossible issues:")
  print("- Check that your dataset and FHIR store exist")
  print("- Verify service account has Healthcare API permissions")
  print("- Ensure gcloud authentication is working")
  print("- Review CONNECT.md for setup instructions")
  
  if type(result) == "table" and result.status then
    print("\nHTTP Status:", result.status)
    if result.body and result.body.error then
      print("Error:", result.body.error.message or "Unknown error")
    end
  end
end

print("\n=== Script Complete ===")
print("\nNote: This script uses gcloud CLI authentication.")
print("For production use with service account keys, implement:")
print("- Proper RSA-SHA256 JWT signing")  
print("- Token caching and refresh logic")
print("- Error handling and retry logic") 