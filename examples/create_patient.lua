#!/usr/bin/env lua

local fhir = require("fhir")

-- Get optional first and last name from CLI arguments
local given_name = arg[1] or "Scottie"
local family_name = arg[2] or "Pippen"

-- Create client (automatically loads .env configuration)
local client = fhir.client.new({
  backend = "google_healthcare"
})

-- Create patient resource
local patient = fhir.resource:new("Patient", {
  active = true,
  name = {
    {
      use = "official",
      family = family_name,
      given = {given_name}
    }
  },
  gender = "male",
  birthDate = "1980-05-15"
})

-- Create the patient
local created_patient = client:create(patient)
print("Created patient ID:", created_patient.id) 