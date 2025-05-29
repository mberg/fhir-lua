package = "fhir-skeleton"
version = "0.2.0-1"
source = { url = "git+https://example.com/fhir-lua-skeleton.git" }
description = {
  summary   = "FHIR client library for Lua (sync + async)",
  detailed  = [[Lua port of the popular fhir-py client: resource CRUD, fluent
                 search builder, coroutine‑based async wrapper, and reference
                 helpers. Includes Google Healthcare API backend support.]],
  homepage  = "https://github.com/yourname/fhir-lua",
  license   = "MIT",
}
dependencies = {
  "lua >= 5.1",
  "luasocket",
  "lua-cjson",
  "luasec",
  "lua-dotenv"
}
build = {
  type    = "builtin",
  modules = {
    ["fhir.init"]                          = "fhir/init.lua",
    ["fhir.client"]                        = "fhir/client.lua",
    ["fhir.async_client"]                  = "fhir/async_client.lua",
    ["fhir.resource"]                      = "fhir/resource.lua",
    ["fhir.searchset"]                     = "fhir/searchset.lua",
    ["fhir.reference"]                     = "fhir/reference.lua",
    ["fhir.util.http"]                     = "fhir/util/http.lua",
    ["fhir.util.serializer"]               = "fhir/util/serializer.lua",
    ["fhir.util.params"]                   = "fhir/util/params.lua",
    ["fhir.backends.google_healthcare"]    = "fhir/backends/google_healthcare.lua",
    ["fhir.backends.google_client"]        = "fhir/backends/google_client.lua",
  },
} 