defmodule Elisnake.Gateway.Router do
  @moduledoc """
  """
  use Plug.Router

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:dispatch)

  get "/api/v1/ping" do
    json_resp(conn, 200, "ok")
  end

  match _ do
    send_resp(conn, 404, "not found")
  end

  defp json_resp(conn, status_code, result) do
    put_resp_content_type(conn, "application/json")
    |> send_resp(status_code, Jason.encode!(result))
  end
end
