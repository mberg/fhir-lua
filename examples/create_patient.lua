#!/usr/bin/env lua

local fhir = require("fhir")

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
      family = "Smith",
      given = {"John"}
    }
  },
  gender = "male",
  birthDate = "1980-05-15"
})

-- Create the patient
local created_patient = client:create(patient)
print("Created patient ID:", created_patient.id) 