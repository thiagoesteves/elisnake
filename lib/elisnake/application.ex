defmodule Elisnake.Application do
  @moduledoc """
  This is the entry point for the main application
  """
  use Application
  require Logger

  # ----------------------------------------------------------------------------
  # Public APIs
  # ----------------------------------------------------------------------------

  @doc """
  Start all supervised servers and launch plug service
  """
  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
    port = Application.get_env(:elisnake, :port, 4000)

    children = [
      Elisnake.Storage.Game,
      Elisnake.GameSm.Sup,
      {Plug.Cowboy,
       scheme: :http,
       plug: {Elisnake.Router, []},
       options: [port: port, dispatch: dispatch()],
       otp_app: :http_server}
    ]

    Logger.info("#{__MODULE__} created with success, listening at port: #{inspect(port)}")

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_,
       [
         {"/", :cowboy_static, {:priv_file, :elisnake, "index.html"}},
         {"/websocket", Elisnake.Gateway.Websocket, []},
         {"/static/[...]", :cowboy_static, {:priv_dir, :elisnake, "static"}},
         {:_, Plug.Cowboy.Handler, {Elisnake.Gateway.Router, []}}
       ]}
    ]
  end
end
