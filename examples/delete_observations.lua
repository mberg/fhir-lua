#!/usr/bin/env lua

local fhir = require("fhir")

-- Get patient ID from command line
local patient_id = arg[1]

if not patient_id then
  print("Usage: lua delete_observations.lua <patient_id>")
  os.exit(1)
end

-- Create client (loads .env automatically)
local client = fhir.client.new({
  backend = "google_healthcare",
})

-- Search for observations referencing the patient
local bundle = client:resources("Observation")
  :search({ subject = "Patient/" .. patient_id })
  :fetch()

local deleted = 0
for _, entry in ipairs(bundle.entry or {}) do
  if entry.resource and entry.resource.id then
    client:delete("Observation", entry.resource.id)
    deleted = deleted + 1
  end
end

print("Deleted", deleted, "observation(s) for patient:", patient_id)

