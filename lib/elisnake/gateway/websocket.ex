defmodule Elisnake.Gateway.Websocket do
  @moduledoc """
  """
  @behaviour :cowboy_websocket

  require Logger

  ### ==========================================================================
  ### Local Defines
  ### ==========================================================================

  ### ==========================================================================
  ### Callback implementation
  ### ==========================================================================

  def init(req0, opts) do
    Logger.info("#{__MODULE__} initialized with success")
    {:cowboy_websocket, req0, opts}
  end

  def websocket_init(state) do
    Logger.info("Starting Websocket server at PID: #{inspect(self())}")
    {[{:text, "Elisnake is alive!"}], state}
  end

  def websocket_handle({:text, json_bin}, state) do
    Jason.decode!(json_bin)
    |> execute

    {[], state}
  end

  def websocket_info({:snake_sm_updated, snake_position, points, {fx, fy}}, state) do
    # prepare Json file to be sent throught websockets
    update_map =
      snake_position
      |> List.foldl(
        %{counter: 0, snake: %{}},
        fn {x, y}, %{counter: acc, snake: snake} ->
          %{
            counter: acc + 1,
            snake: snake |> Map.put("p" <> to_string(acc), %{x: x, y: y})
          }
        end
      )
      |> Map.delete(:counter)
      |> Map.put(:update, :elisnake_sm)
      |> Map.put(:food, %{x: fx, y: fy})
      |> Map.put(:points, points)

    {[{:text, Jason.encode!(update_map)}], state}
  end

  def websocket_info({:snake_sm_game_over, _GenStateData}, state) do
    Logger.debug("Game Over")
    {:reply, {:close, 1000, "Game Over"}, state}
  end

  def websocket_info({:elisnake_sm, payers_list}, state) do
    new_map =
      payers_list
      |> List.foldl(
        %{best_players: %{elisnake_sm: %{}}},
        fn {name, points}, %{best_players: %{elisnake_sm: acc}} ->
          %{best_players: %{elisnake_sm: Map.put(acc, "#{name}", points)}}
        end
      )

    {[{:text, Jason.encode!(new_map)}], state}
  end

  ### ==========================================================================
  ### Private functions
  ### ==========================================================================
  @spec execute(map()) :: :ok
  defp execute(%{"game" => "elisnake_sm", "action" => action, "user" => user}) do
    Elisnake.GameSm.action(user, action2atom(action))
    :ok
  end

  defp execute(%{"game" => "elisnake_sm", "user" => user}) do
    # Create game and ignore if the game is already created
    case Elisnake.GameSm.Sup.create_game(user, {20, 20}, 200) do
      {:ok, _} -> :none
      {:error, {:already_started, _}} -> :none
    end

    {:ok, _} = Elisnake.GameSm.start_game(user)
    :ok
  end

  defp execute(%{"game" => "elisnake_sm", "request" => "get_best_player"}) do
    {:ok, players_list} = Elisnake.Storage.Game.get_best_player(Elisnake.GameSm)
    Process.send(self(), {:elisnake_sm, players_list}, [])
    :ok
  end

  def action2atom("up"), do: :up
  def action2atom("down"), do: :down
  def action2atom("right"), do: :right
  def action2atom("left"), do: :left
end
