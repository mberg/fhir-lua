#!/usr/bin/env lua

--[[
Google Healthcare API Example for FHIR-Lua

This example demonstrates how to use FHIR-Lua with Google Healthcare API.
Before running this example:

1. Set up Google Cloud Healthcare API (see CONNECT.md)
2. Authenticate with gcloud CLI:
   gcloud auth application-default login
3. Update the configuration below with your actual values
4. Run: lua examples/google_healthcare_example.lua
]]

local fhir = require("fhir")

-- Configuration - UPDATE THESE VALUES
local config = {
  backend = "google_healthcare",
  google_config = {
    project_id = "your-project-id",        -- Replace with your GCP project ID
    location = "us-central1",               -- Replace with your region
    dataset_id = "my-fhir-dataset",        -- Replace with your dataset ID
    fhir_store_id = "my-fhir-store"        -- Replace with your FHIR store ID
  }
}

print("=== FHIR-Lua Google Healthcare API Example ===\n")

-- Create client
print("1. Connecting to Google Healthcare API...")
local client = fhir.client.new(config)
print("✅ Connected to:", client.baseUrl)

-- Create a sample patient
print("\n2. Creating a sample patient...")
local patient = fhir.resource:new("Patient", {
  active = true,
  name = {
    {
      family = "TestPatient",
      given = {"Demo", "Example"}
    }
  },
  gender = "unknown",
  birthDate = "1990-01-01",
  telecom = {
    {
      system = "email",
      value = "demo@example.com",
      use = "home"
    }
  }
})

local ok, result = pcall(function()
  return client:create(patient)
end)

if ok then
  local created_patient = result
  print("✅ Created patient with ID:", created_patient.id)
  
  -- Read the patient back
  print("\n3. Reading patient back...")
  local retrieved_patient = client:get("Patient", created_patient.id)
  print("✅ Retrieved patient:", retrieved_patient.name[1].family)
  
  -- Update the patient
  print("\n4. Updating patient...")
  retrieved_patient.telecom = {
    {
      system = "phone",
      value = "555-1234",
      use = "mobile"
    }
  }
  
  local updated_patient = client:save(retrieved_patient)
  print("✅ Updated patient contact info")
  
  -- Search for patients
  print("\n5. Searching for patients...")
  local search_results = client:google_search("Patient", {
    family = "TestPatient",
    _count = 5
  })
  
  local patient_count = 0
  if search_results.entry then
    patient_count = #search_results.entry
  end
  print("✅ Found", patient_count, "patients matching 'TestPatient'")
  
  -- Clean up - delete the test patient
  print("\n6. Cleaning up...")
  client:delete("Patient", created_patient.id)
  print("✅ Deleted test patient")
  
else
  print("❌ Error creating patient:", result)
  print("\nPossible issues:")
  print("- Check your Google Cloud configuration in the script")
  print("- Ensure you're authenticated: gcloud auth application-default login")
  print("- Verify your Healthcare API setup (see CONNECT.md)")
  print("- Check that your dataset and FHIR store exist")
end

print("\n=== Example Complete ===")
print("\nFor more information, see:")
print("- CONNECT.md for setup instructions")
print("- README.md for general usage")
print("- Google Cloud Healthcare API documentation") 