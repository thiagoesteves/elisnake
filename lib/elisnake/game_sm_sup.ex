defmodule Elisnake.GameSm.Sup do
  @moduledoc """
  This supervisor will handle all the individuals XFP that will be
  created dinamically by the user
  """
  use Supervisor
  require Logger

  ### ==========================================================================
  ### Supervised server default values
  ### ==========================================================================
  @default_matrix {19, 19}
  @default_loop 1

  ### ==========================================================================
  ### Supervisor Callbacks
  ### ==========================================================================
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = []
    Logger.info("#{__MODULE__} created with success")
    Supervisor.init(children, strategy: :one_for_one, max_restarts: 10, max_seconds: 5)
  end

  ### ==========================================================================
  ### Public API functions
  ### ==========================================================================
  @spec create_game(String.t(), {integer(), integer()}, integer()) ::
          {:ok, pid()} | {:error, {atom(), any()}}
  def create_game(username, matrix \\ @default_matrix, loop_time \\ @default_loop) do
    spec = %{
      id: {username, __MODULE__},
      start: {Elisnake.GameSm, :start_link, [username, matrix, loop_time]},
      restart: :transient
    }

    # Check if the user game has already finished
    if children_pid(username) == :undefined do
      :ok = Supervisor.delete_child(__MODULE__, spec.id)
    end

    Supervisor.start_child(__MODULE__, spec)
  end

  @spec children_pid(String.t()) :: pid() | nil | :undefined
  def children_pid(username) when is_binary(username) do
    Supervisor.which_children(__MODULE__)
    |> Enum.find_value(fn
      {{^username, __MODULE__}, pid, _, _} -> pid
      _ -> false
    end)
  end

  ### ==========================================================================
  ### Private functions
  ### ==========================================================================
end
