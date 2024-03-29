import Config

# Configuration added to work with phoenix
config :phoenix_distillery, PhoenixDistillery.Endpoint,
  http: [port: {:system, "PORT"}],
  # This is critical for ensuring web-sockets properly authorize.
  url: [host: "localhost", port: {:system, "PORT"}],
  cache_static_manifest: "priv/static/manifest.json",
  server: true,
  root: ".",
  version: Mix.Project.config()[:version]

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.
#
# Note we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the `mix phx.digest` task,
# which you should run after static files are built and
# before starting your production server.
config :elisnake, Elisnake.Router,
  url: [host: "example.com", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger,
  level: :info,
  format: "[$date] [$time] [$level] $message\n"
