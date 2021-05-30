defmodule Elisnake.Storage.Game do
  @moduledoc """
  This module will handle the database
  """

  use GenServer
  require Logger

  ### ==========================================================================
  ### Local Defines
  ### ==========================================================================

  # Internal database to accumulate the user points
  @user_points :user_points

  # Internal database to save states (if needed)
  @save_game_states :save_states

  ### ==========================================================================
  ### Public functions
  ### ==========================================================================

  @spec start_link(any()) :: {:ok, pid()} | :ignore | {:error, term()}
  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  ### ==========================================================================
  ### gen_server callbacks
  ### ==========================================================================

  @spec init(list()) :: {:ok, list()}
  @impl true
  def init([]) do
    # Create two tables to handle the points and last state
    :ets.new(@save_game_states, [:set, :named_table])
    :ets.new(@user_points, [:set, :named_table])
    Logger.info("[#{__MODULE__}] has started with success")
    {:ok, []}
  end

  @impl true
  def handle_call({:get_user_points, username, game}, _From, state) do
    res = get_user_points_priv(username, game)
    {:reply, res, state}
  end

  def handle_call({:get_best_player, game}, _From, state) do
    res = get_best_player_priv(game)
    {:reply, res, state}
  end

  def handle_call({:save_game_state, username, game, received_state}, _From, state) do
    :ets.insert(@save_game_states, db_game_kvs(username, game, received_state))
    {:reply, {:ok, 0}, state}
  end

  def handle_call({:get_game_state, username, game}, _From, state) do
    res =
      case :ets.lookup(@save_game_states, {username, game}) do
        [{{^username, ^game}, game_last_state}] -> game_last_state
        _ -> :undefined
      end

    {:reply, {:ok, res}, state}
  end

  @impl true
  def handle_cast({:add_user_points, username, game, points}, state) do
    add_user_points_priv(username, game, points)
    {:noreply, state}
  end

  @impl true
  def handle_info(_Msg, state), do: {:noreply, state}

  @impl true
  def terminate(:normal, _State), do: :ok

  @impl true
  def code_change(_OldVsn, state, _Extra), do: {:ok, state}

  ### ==========================================================================
  ### Public functions
  ### ==========================================================================

  @doc """
    This function returns the current number of points for this 
    user. If the user doesn't exist, it will be created.

    @param username User ID name 
    @param game game name 
  """
  @spec get_user_points(String.t(), atom()) :: {:ok | :error, integer()}
  def get_user_points(username, game) when is_binary(username) and is_atom(game) do
    GenServer.call(__MODULE__, {:get_user_points, username, game})
  end

  @doc """
    This function adds points to the respective user, If the user 
    doesn't exist, it will be created.

    @param username User ID name 
    @param game game name 
    @param points Number of points to be added
  """
  @spec add_user_points(String.t(), atom(), integer()) :: :ok
  def add_user_points(username, game, points)
      when is_binary(username) and is_atom(game) and is_integer(points) do
    GenServer.cast(__MODULE__, {:add_user_points, username, game, points})
  end

  @doc """
    This function retrieves the best player for an specific game
    
    @param game game name 
  """
  @spec get_best_player(atom()) :: {:ok, {atom(), integer()}}
  def get_best_player(game) when is_atom(game) do
    GenServer.call(__MODULE__, {:get_best_player, game})
  end

  @doc """
      This function save the user/game state

    @param User User name to be used as key
    @param game game name to be used as key
    @param ReceivedState State to be saved 
  """
  @spec save_game_state(String.t(), atom(), any()) :: {:ok, integer()}
  def save_game_state(username, game, received_state)
      when is_binary(username) and is_atom(game) do
    GenServer.call(__MODULE__, {:save_game_state, username, game, received_state})
  end

  @doc """
    This function retrieves the last game state based on the passed keys

    @param username username name to be used as key
    @param game game name to be used as key
  """
  @spec get_game_state(String.t(), atom()) :: {:ok, any() | :undefined}
  def get_game_state(username, game) when is_binary(username) and is_atom(game) do
    GenServer.call(__MODULE__, {:get_game_state, username, game})
  end

  ### ==========================================================================
  ### Internal Functions
  ### ==========================================================================

  defp get_user_points_priv(username, game) do
    # Check the user exist, if not, create one
    case :ets.lookup(@user_points, {username, game}) do
      [{{^username, ^game}, points}] ->
        {:ok, points}

      [] ->
        :ets.insert(@user_points, db_kvs(username, game, 0))
        {:ok, 0}
    end
  end

  defp add_user_points_priv(username, game, points_to_add) do
    # Check the user exist, if not, create one and add points
    current_points =
      case :ets.lookup(@user_points, {username, game}) do
        [{{^username, ^game}, points}] -> points
        [] -> 0
      end

    :ets.insert(@user_points, db_kvs(username, game, current_points + points_to_add))
  end

  defp get_best_player_priv(game) do
    # Search the entire table for the User ID (must be optimized)
    %{players: players_list} =
      :ets.foldl(
        fn {{username, game_name}, points}, %{max: max_p, players: players} = acc ->
          case {game_name, points} do
            {^game, p} when p > max_p -> %{max: p, players: [{username, p}]}
            {^game, p} when p === max_p -> %{max: p, players: [{username, p} | players]}
            _ -> acc
          end
        end,
        %{max: 0, players: []},
        @user_points
      )

    {:ok, players_list}
  end

  defp db_game_kvs(username, game, state), do: {{username, game}, state}

  defp db_kvs(id, game, points), do: {{id, game}, points}
end
