-- Google Healthcare API specific client extensions
-- This module adds Google-specific methods to FHIR clients when using the Google Healthcare backend

local GoogleClient = {}

-- Google Healthcare specific convenience methods
function GoogleClient.google_search(client, resource_type, params)
  if not client:is_google_healthcare() then
    error("google_search only available with Google Healthcare backend")
  end
  return client.http:search_resources(resource_type, params)
end

function GoogleClient.google_create_resource(client, resource_type, resource_data)
  if not client:is_google_healthcare() then
    error("google_create_resource only available with Google Healthcare backend")
  end
  return client.http:create_resource(resource_type, resource_data)
end

function GoogleClient.google_get_resource(client, resource_type, resource_id)
  if not client:is_google_healthcare() then
    error("google_get_resource only available with Google Healthcare backend")
  end
  return client.http:get_resource(resource_type, resource_id)
end

function GoogleClient.google_update_resource(client, resource_type, resource_id, resource_data)
  if not client:is_google_healthcare() then
    error("google_update_resource only available with Google Healthcare backend")
  end
  return client.http:update_resource(resource_type, resource_id, resource_data)
end

function GoogleClient.google_delete_resource(client, resource_type, resource_id)
  if not client:is_google_healthcare() then
    error("google_delete_resource only available with Google Healthcare backend")
  end
  return client.http:delete_resource(resource_type, resource_id)
end

-- Function to extend a client with Google-specific methods
function GoogleClient.extend_client(client)
  -- Add Google-specific methods to the client instance
  client.google_search = function(self, resource_type, params)
    return GoogleClient.google_search(self, resource_type, params)
  end
  
  client.google_create_resource = function(self, resource_type, resource_data)
    return GoogleClient.google_create_resource(self, resource_type, resource_data)
  end
  
  client.google_get_resource = function(self, resource_type, resource_id)
    return GoogleClient.google_get_resource(self, resource_type, resource_id)
  end
  
  client.google_update_resource = function(self, resource_type, resource_id, resource_data)
    return GoogleClient.google_update_resource(self, resource_type, resource_id, resource_data)
  end
  
  client.google_delete_resource = function(self, resource_type, resource_id)
    return GoogleClient.google_delete_resource(self, resource_type, resource_id)
  end
  
  return client
end

return GoogleClient 