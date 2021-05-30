Application.load(:elisnake)

for app <- Application.spec(:elisnake, :applications) do
  Application.ensure_all_started(app)
end

Logger.configure(level: :error)

ExUnit.start()
