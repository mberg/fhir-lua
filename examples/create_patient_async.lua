#!/usr/bin/env lua

local AsyncClient = require("fhir.async_client")
local Resource = require("fhir.resource")

-- Get optional first and last name from CLI arguments
local given_name = arg[1] or "Shaka"
local family_name = arg[2] or "Zulu"

-- Create async client (automatically loads .env configuration)
local client = AsyncClient.new({
  backend = "google_healthcare"
})

-- Create patient resource
local patient = Resource:new("Patient", {
  active = true,
  name = {
    {
      use = "official",
      family = family_name,
      given = {given_name}
    }
  },
  gender = "female",
  birthDate = "2025-05-24"
})

-- Create the patient using async coroutine
local co = client:create(patient)
local created_patient = co()  -- resume coroutine until completion
print("Created patient ID:", created_patient.id) 