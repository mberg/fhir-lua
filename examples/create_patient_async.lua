#!/usr/bin/env lua

local AsyncClient = require("fhir.async_client")
local Resource = require("fhir.resource")

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
      family = "Milla",
      given = {"Roger"}
    }
  },
  gender = "male",
  birthDate = "1980-05-15"
})

-- Create the patient using async coroutine
local co = client:create(patient)
local created_patient = co()  -- resume coroutine until completion
print("Created patient ID:", created_patient.id) 