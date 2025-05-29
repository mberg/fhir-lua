#!/usr/bin/env lua

local AsyncClient = require("fhir.async_client")
local Resource = require("fhir.resource")

-- Create async client (automatically loads .env configuration)
local client = AsyncClient.new({
  backend = "google_healthcare"
})

-- Get patient ID from command line argument or use default
local patient_id = arg[1] or "f16195fd-25d0-4294-ad6f-8c1046897293"

print("Recording measles vaccine for patient:", patient_id)

-- Create immunization resource for measles vaccine
local immunization = Resource:new("Immunization", {
  status = "completed",
  vaccineCode = {
    coding = {
      {
        system = "http://hl7.org/fhir/sid/cvx",
        code = "03",
        display = "MMR"
      }
    },
    text = "Measles, Mumps and Rubella vaccine"
  },
  patient = {
    reference = "Patient/" .. patient_id
  },
  occurrenceDateTime = "2024-01-15T10:30:00Z",
  primarySource = true
})

-- Record the immunization
local co = client:create(immunization)
local created_immunization = co()

if created_immunization then
  print("✅ Immunization recorded successfully!")
  print("   Immunization ID:", created_immunization.id)
  print("   Patient ID:", patient_id)
  print("   Patient Reference:", created_immunization.patient.reference)
  print("   Vaccine:", created_immunization.vaccineCode.text)
  if created_immunization.vaccineCode.coding and created_immunization.vaccineCode.coding[1] then
    local coding = created_immunization.vaccineCode.coding[1]
    print("   Vaccine Code:", coding.code, "(" .. coding.display .. ")")
    print("   Code System:", coding.system)
  end
  print("   Date Given:", created_immunization.occurrenceDateTime)
  print("   Status:", created_immunization.status)
  print("   Primary Source:", created_immunization.primarySource)
  
  -- Verify by reading the immunization back
  print("\n🔍 Verifying immunization record...")
  local verify_co = client:get("Immunization", created_immunization.id)
  local retrieved_immunization = verify_co()
  
  if retrieved_immunization then
    print("✅ Immunization verification successful")
    print("   Retrieved ID:", retrieved_immunization.id)
    print("   Retrieved vaccine:", retrieved_immunization.vaccineCode.text)
    print("   Retrieved status:", retrieved_immunization.status)
    print("   Retrieved patient:", retrieved_immunization.patient.reference)
  else
    print("❌ Error verifying immunization")
  end
else
  print("❌ Error recording immunization")
end
