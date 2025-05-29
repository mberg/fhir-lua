#!/usr/bin/env lua

local AsyncClient = require("fhir.async_client")
local Resource = require("fhir.resource")

-- Create async client (automatically loads .env configuration)
local client = AsyncClient.new({
  backend = "google_healthcare"
})

-- Get search parameter from command line
local search_param = arg[1]

if not search_param then
  print("Usage: lua find_patient.lua <patient_id_or_name>")
  print("Examples:")
  print("  lua find_patient.lua f16195fd-25d0-4294-ad6f-8c1046897293")
  print("  lua find_patient.lua 'Roger Milla'")
  print("  lua find_patient.lua Smith")
  os.exit(1)
end

-- Function to display patient information
local function display_patient(patient)
  print("  ID:", patient.id)
  print("  Active:", patient.active)
  if patient.name and patient.name[1] then
    local name = patient.name[1]
    print("  Name:", (name.given and name.given[1] or ""), name.family or "")
  end
  if patient.gender then
    print("  Gender:", patient.gender)
  end
  if patient.birthDate then
    print("  Birth Date:", patient.birthDate)
  end
  print()
end

-- Check if search parameter looks like a UUID (patient ID)
local function is_uuid(str)
  return str:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

if is_uuid(search_param) then
  -- Search by patient ID
  print("Looking up patient by ID:", search_param)
  
  local co = client:get("Patient", search_param)
  local patient = co()  -- resume coroutine until completion
  
  if patient then
    print("Found patient:")
    display_patient(patient)
  else
    print("Patient not found")
  end
else
  -- Search by name
  print("Searching for patients with name:", search_param)
  
  local search_co = client:resources("Patient"):search({name = search_param}):fetch()
  local bundle = search_co()  -- resume coroutine until completion
  
  if bundle and bundle.entry and #bundle.entry > 0 then
    print("Found", #bundle.entry, "patient(s):")
    print()
    for _, entry in ipairs(bundle.entry) do
      if entry.resource then
        display_patient(entry.resource)
      end
    end
  else
    print("No patients found with name:", search_param)
  end
end

