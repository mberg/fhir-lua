# Connecting to Google Healthcare API

This guide shows how to connect FHIR-Lua to Google Cloud Healthcare API for production FHIR operations.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Phase 1: Google Cloud Setup](#phase-1-google-cloud-setup)
- [Phase 2: Authentication Setup](#phase-2-authentication-setup)
- [Phase 3: Using FHIR-Lua with Google Healthcare API](#phase-3-using-fhir-lua-with-google-healthcare-api)
- [Code Examples](#code-examples)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

## Prerequisites

- Google Cloud Platform account
- `gcloud` CLI installed and configured
- FHIR-Lua library installed
- Basic understanding of FHIR resources

## Phase 1: Google Cloud Setup

### 1. Create a Google Cloud Project

```bash
# Create a new project (replace PROJECT_ID with your desired ID)
gcloud projects create YOUR_PROJECT_ID

# Set the project as default
gcloud config set project YOUR_PROJECT_ID
```

### 2. Enable Required APIs

```bash
# Enable the Healthcare API
gcloud services enable healthcare.googleapis.com

# Enable other helpful APIs
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable iam.googleapis.com
```

### 3. Create Healthcare Dataset and FHIR Store

```bash
# Set variables (customize these values)
export PROJECT_ID="your-project-id"
export LOCATION="us-central1"
export DATASET_ID="my-fhir-dataset"
export FHIR_STORE_ID="my-fhir-store"

# Create dataset
gcloud healthcare datasets create $DATASET_ID \
  --location=$LOCATION

# Create FHIR store
gcloud healthcare fhir-stores create $FHIR_STORE_ID \
  --dataset=$DATASET_ID \
  --location=$LOCATION \
  --version=R4
```

## Phase 2: Authentication Setup

### Option A: Development Setup (gcloud CLI)

**Recommended for development and testing:**

```bash
# Login to gcloud
gcloud auth login

# Set up Application Default Credentials
gcloud auth application-default login
```

### Option B: Production Setup (Service Account)

**Recommended for production deployments:**

#### 1. Create Service Account

```bash
# Create service account
gcloud iam service-accounts create healthcare-fhir-client \
  --display-name="Healthcare FHIR Client" \
  --description="Service account for FHIR operations"

# Get the service account email
export SA_EMAIL="healthcare-fhir-client@${PROJECT_ID}.iam.gserviceaccount.com"
```

#### 2. Grant IAM Roles

```bash
# Grant Healthcare Dataset Administrator role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/healthcare.datasetAdmin"

# Grant Healthcare FHIR Store Administrator role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/healthcare.fhirStoreAdmin"
```

**Alternative: Fine-grained permissions**

For production, consider more specific roles:
- `roles/healthcare.fhirResourceReader` - Read-only access
- `roles/healthcare.fhirResourceEditor` - Read/write access
- `roles/healthcare.fhirResourceViewer` - View metadata only

#### 3. Create Service Account Key

```bash
# Create and download service account key
gcloud iam service-accounts keys create ~/healthcare-sa-key.json \
  --iam-account=$SA_EMAIL

# Set environment variable (for local development)
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/healthcare-sa-key.json"
```

#### 4. Verify Setup

```bash
# Test authentication
gcloud auth application-default print-access-token

# Test Healthcare API access
gcloud healthcare datasets list --location=$LOCATION
```

## Phase 3: Using FHIR-Lua with Google Healthcare API

### Basic Configuration

```lua
local fhir = require("fhir")

-- Configuration for Google Healthcare API
local config = {
  backend = "google_healthcare",
  google_config = {
    project_id = "your-project-id",
    location = "us-central1",
    dataset_id = "my-fhir-dataset",
    fhir_store_id = "my-fhir-store"
  }
}

-- Create client
local client = fhir.client.new(config)
```

### Authentication Methods

The Google Healthcare backend supports multiple authentication methods:

#### Method 1: gcloud CLI (Development)
```lua
-- No additional configuration needed
-- Will automatically use gcloud credentials
local client = fhir.client.new(config)
```

#### Method 2: Service Account Key (Production)
```lua
-- Load service account key from file
local config = {
  backend = "google_healthcare",
  google_config = {
    project_id = "your-project-id",
    location = "us-central1", 
    dataset_id = "my-fhir-dataset",
    fhir_store_id = "my-fhir-store",
    service_account_key = "/path/to/service-account-key.json"
  }
}

local client = fhir.client.new(config)
```

> **Note:** Service account key authentication requires proper JWT signing implementation. For production use, ensure you have a proper RSA-SHA256 signing library or use gcloud CLI authentication.

## Code Examples

### Example 1: Create a Patient

```lua
local fhir = require("fhir")

-- Setup client
local client = fhir.client.new({
  backend = "google_healthcare",
  google_config = {
    project_id = "your-project-id",
    location = "us-central1",
    dataset_id = "my-fhir-dataset", 
    fhir_store_id = "my-fhir-store"
  }
})

-- Create a patient resource
local patient = fhir.resource:new("Patient", {
  active = true,
  name = {
    {
      family = "Doe",
      given = {"John", "Robert"}
    }
  },
  gender = "male",
  birthDate = "1990-01-01"
})

-- Save to Google Healthcare API
local created_patient, response = client:create(patient)
print("Created patient with ID:", created_patient.id)
```

### Example 2: Search for Patients

```lua
-- Search using standard FHIR search
local searchSet = client:resources("Patient")
                       :search({name = "Doe", gender = "male"})
                       :limit(10)
                       :sort("birthdate")

local bundle = searchSet:fetch()
print("Found", #(bundle.entry or {}), "patients")

-- Or use Google Healthcare specific search
local results = client:google_search("Patient", {
  name = "Doe",
  gender = "male",
  _count = 10
})
```

### Example 3: Update a Patient

```lua
-- Get existing patient
local patient = client:get("Patient", "patient-id-123")

-- Update patient data
patient.telecom = {
  {
    system = "phone",
    value = "555-1234",
    use = "home"
  }
}

-- Save changes
local updated_patient = client:save(patient)
print("Updated patient:", updated_patient.id)
```

### Example 4: Async Operations

```lua
local AsyncClient = require("fhir.async_client")

local async_client = AsyncClient.new({
  backend = "google_healthcare",
  google_config = {
    project_id = "your-project-id",
    location = "us-central1",
    dataset_id = "my-fhir-dataset",
    fhir_store_id = "my-fhir-store"
  }
})

-- Async create
local create_coroutine = async_client:create(patient)
local created_patient = create_coroutine() -- Resume until completion

print("Async created patient:", created_patient.id)
```

### Example 5: Error Handling

```lua
local ok, err = pcall(function()
  return client:get("Patient", "non-existent-id")
end)

if not ok then
  print("Error occurred:")
  print("Status:", err.status)
  print("Message:", err.message or "Unknown error")
  if err.body and err.body.issue then
    for _, issue in ipairs(err.body.issue) do
      print("Issue:", issue.severity, issue.code, issue.diagnostics)
    end
  end
end
```

## Troubleshooting

### Common Issues

#### 1. Authentication Errors

**Error:** `No authentication method available`

**Solution:**
```bash
# Ensure gcloud is authenticated
gcloud auth application-default login

# Verify credentials work
gcloud auth application-default print-access-token
```

#### 2. Permission Denied

**Error:** `403 Forbidden` or permission denied

**Solution:**
- Verify IAM roles are correctly assigned
- Check that the service account has the right permissions
- Ensure the dataset and FHIR store exist

#### 3. Invalid Project/Dataset/Store

**Error:** `404 Not Found`

**Solution:**
```bash
# Verify your resources exist
gcloud healthcare datasets list --location=us-central1
gcloud healthcare fhir-stores list --dataset=DATASET_ID --location=us-central1
```

#### 4. JWT Signing Not Implemented

**Error:** `JWT signing not implemented`

**Solution:**
- Use gcloud CLI authentication for development
- Implement proper RSA-SHA256 JWT signing for production service account authentication
- Consider using Google Cloud client libraries instead

### Debug Mode

Enable detailed logging:

```lua
-- Add debug logging to see HTTP requests
local client = fhir.client.new({
  backend = "google_healthcare",
  google_config = {
    -- ... your config
    debug = true  -- Enable debug mode
  }
})
```

## Security Best Practices

### 1. Service Account Security

- **Principle of Least Privilege:** Only grant minimum necessary roles
- **Key Rotation:** Regularly rotate service account keys
- **Key Storage:** Never commit keys to version control
- **Environment Variables:** Use environment variables for sensitive configuration

### 2. Network Security

```lua
-- Use environment variables for sensitive data
local config = {
  backend = "google_healthcare",
  google_config = {
    project_id = os.getenv("GOOGLE_PROJECT_ID"),
    location = os.getenv("GOOGLE_LOCATION"),
    dataset_id = os.getenv("GOOGLE_DATASET_ID"),
    fhir_store_id = os.getenv("GOOGLE_FHIR_STORE_ID")
  }
}
```

### 3. Production Deployment

For production deployments:

1. **Use Managed Identity:** When possible, use Google Cloud managed identities
2. **Private Networks:** Deploy within Google Cloud VPC for network isolation
3. **Audit Logging:** Enable Cloud Audit Logs for Healthcare API
4. **Monitoring:** Set up monitoring and alerting for API usage

### 4. Data Privacy

- Ensure compliance with HIPAA, GDPR, and other relevant regulations
- Use Google Cloud's BAA (Business Associate Agreement) for HIPAA compliance
- Implement proper data retention and deletion policies

## Next Steps

1. **Explore FHIR Resources:** Learn about different FHIR resource types
2. **Implement Search:** Build complex FHIR search queries
3. **Add Validation:** Implement FHIR resource validation
4. **Monitoring:** Set up logging and monitoring for your application
5. **Scaling:** Consider implementing connection pooling for high-traffic applications

For more information, see:
- [Google Cloud Healthcare API Documentation](https://cloud.google.com/healthcare-api/docs)
- [FHIR R4 Specification](https://hl7.org/fhir/R4/)
- [Google Cloud IAM Documentation](https://cloud.google.com/iam/docs) 