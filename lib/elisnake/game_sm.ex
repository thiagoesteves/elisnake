defmodule Elisnake.GameSm do
  @moduledoc """
  This module is the game state machine that plays the snake game
  """
  @behaviour :gen_statem
  require Logger

  ### ==========================================================================
  ### Local Defines
  ### ==========================================================================
  @loop_msg :loop

  # Possible moviments
  @move_up :up
  @move_down :down
  @move_right :right
  @move_left :left

  # Defines for points
  @points_by_loop_time 10
  @points_by_eaten_food 50

  ### ==========================================================================
  ### gen_statem configuration
  ### ==========================================================================
  @impl true
  def callback_mode() do
    [:state_functions, :state_enter]
  end

  ### ==========================================================================
  ### GenServer Callbacks
  ### ==========================================================================

  @spec start_link(String.t(), String.t(), String.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(username, matrix, loop_time) do
    Logger.debug("#{__MODULE__} created with success for ")

    :gen_statem.start_link(
      __MODULE__,
      {username, matrix, loop_time},
      []
    )
  end

  @impl true
  def init({username, matrix, loop_time}) do
    # Allow terminate being called before crash
    Process.flag(:trap_exit, true)

    {next_state, gen_state_data} =
      case Elisnake.Storage.Game.get_game_state(username, __MODULE__) do
        {:ok, :undefined} ->
          {:join,
           %{
             matrix: matrix,
             username: username,
             points: :undefined,
             snake_pos: [{1, 1}],
             last_action: :idle,
             loop_time: loop_time,
             food: {0, 0}
           }}

        {:ok, {old_state, old_gen_state_data}} ->
          Elisnake.Storage.Game.save_game_state(username, __MODULE__, :undefined)
          {old_state, old_gen_state_data}
      end

    # Start the collectors dispatching
    Process.send(self(), @loop_msg, [])

    Logger.info("[#{__MODULE__}] has started for the username: #{username}")
    {:ok, next_state, gen_state_data}
  end

  @impl true
  def terminate(:normal, _, _), do: :ok

  def terminate(reason, state, %{username: username} = gen_state_data) do
    Logger.error("I'm Terminating now Data: #{inspect(reason)} #{inspect(gen_state_data)}")
    Elisnake.Storage.Game.save_game_state(username, __MODULE__, {state, gen_state_data})
    :ok
  end

  @impl true
  def code_change(_old_version, state, %{username: username} = gen_state_data, _extra) do
    Logger.warn("I'm changing my current version #{inspect(state)}")
    Elisnake.Storage.Game.save_game_state(username, __MODULE__, {state, gen_state_data})
    {:ok, state, gen_state_data}
  end

  ### ==========================================================================
  ### gen_statem states
  ### ==========================================================================

  ## JOIN STATE ================================================================
  def join(:enter, _OldState, %{username: username} = gen_state_data) do
    Logger.info("join - enter state for username: #{username}")
    # Capture information from database
    {:ok, points} = Elisnake.Storage.Game.get_user_points(username, __MODULE__)
    {:keep_state, %{gen_state_data | points: points}}
  end

  def join(
        {:call, from},
        {:start_game},
        %{matrix: {max_x, max_y}, snake_pos: snake_position} = gen_state_data
      ) do
    Logger.debug("Starting Game")
    # Create food for the snake
    food = food_position(max_x, max_y, snake_position)
    {:next_state, :play, %{gen_state_data | food: food}, [{:reply, from, {:ok, 0}}]}
  end

  def join(:info, msg, state), do: handle_common(__ENV__.function, msg, state)

  ## JOIN STATE ================================================================
  def play(:enter, _OldState, %{loop_time: loop_time} = gen_state_data) do
    Logger.debug("Play - enter state")
    # Start the loop control, which will check and play with the user
    Process.send_after(self(), @loop_msg, loop_time)
    {:keep_state, gen_state_data}
  end

  # Reject reverse movements for snake greater than 1
  def play(
        :cast,
        {:action, @move_up},
        %{last_action: @move_down, snake_pos: [_, _ | _]} = gen_state_data
      ) do
    Logger.debug("Reverse moviment is not allowed")
    {:keep_state, gen_state_data}
  end

  def play(
        :cast,
        {:action, @move_down},
        %{last_action: @move_up, snake_pos: [_, _ | _]} = gen_state_data
      ) do
    Logger.debug("Reverse moviment is not allowed")
    {:keep_state, gen_state_data}
  end

  def play(
        :cast,
        {:action, @move_right},
        %{last_action: @move_left, snake_pos: [_, _ | _]} = gen_state_data
      ) do
    Logger.debug("Reverse moviment is not allowed")
    {:keep_state, gen_state_data}
  end

  def play(
        :cast,
        {:action, @move_left},
        %{last_action: @move_right, snake_pos: [_, _ | _]} = gen_state_data
      ) do
    Logger.debug("Reverse moviment is not allowed")
    {:keep_state, gen_state_data}
  end

  # Update new action
  def play(:cast, {:action, action}, gen_state_data) do
    Logger.debug("Moving the User")
    {:keep_state, %{gen_state_data | last_action: action}}
  end

  # In case the game was already started
  def play({:call, from}, {:start_game}, gen_state_data) do
    {:keep_state, gen_state_data, [{:reply, from, {:ok, :already_started}}]}
  end

  # Execute loop update
  def play(:info, @loop_msg, %{loop_time: loop_time} = gen_state_data) do
    Logger.debug("Play - Action")
    # Send message to keep the loop
    Process.send_after(self(), @loop_msg, loop_time)

    case update_user_actions(gen_state_data) do
      # keep the cycle running
      {:keep_state, new_state} ->
        {:keep_state, new_state}

      # Game Over
      {:end_game, new_state} ->
        {:next_state, :game_over, new_state}
    end
  end

  def play(:info, msg, state), do: handle_common(__ENV__.function, msg, state)

  ## GAME OVER STATE ================================================================
  def game_over(:info, msg, state), do: handle_common(__ENV__.function, msg, state)

  def game_over(_, _, %{username: username} = gen_state_data) do
    Logger.info("Game Over - enter state for username #{username}")
    notify_game_over(gen_state_data)
    {:stop, :normal, gen_state_data}
  end

  ### ==========================================================================
  ### Public Game functions
  ### ==========================================================================

  @doc """
    This function starts the game
    
    @param UserName The respective user name for the game
  """
  @spec start_game(String.t()) :: {:ok, integer() | :already_started}
  def start_game(username) when is_binary(username) do
    :gproc.ensure_reg(gproc_player_group(username))

    Elisnake.GameSm.Sup.children_pid(username)
    |> :gen_statem.call({:start_game})
  end

  @doc """
    This function execute actions for the player

    @param UserName The respective user name for the game
    @param Action Action to be executed 
  """
  @spec action(String.t(), atom()) :: :ok
  def action(username, action) when is_binary(username) and is_atom(action) do
    Elisnake.GameSm.Sup.children_pid(username)
    |> :gen_statem.cast({:action, action})
  end

  ### ==========================================================================
  ### Private functions
  ### ==========================================================================
  defp handle_common({state, _}, _msg, _gen_state_data) do
    Logger.info("Info Request - My current State: #{state}")
    :keep_state_and_data
  end

  # This function returns an available position to put the food
  defp food_position(max_x, max_y, snake_position) do
    empty_pos = generate_board(max_x, max_y) -- snake_position

    if empty_pos != [] do
      random_index =
        empty_pos
        |> length
        |> :rand.uniform()

      {food_position, _} = List.pop_at(empty_pos, random_index - 1)
      food_position
    else
      nil
    end
  end

  defp generate_board(max_x, max_y) do
    for x <- 0..max_x, y <- 0..max_y, do: {x, y}
  end

  # Update user action and check points
  defp update_user_actions(
         %{
           last_action: :idle,
           snake_pos: snake_position,
           food: food,
           username: username,
           points: points
         } = state
       ) do
    Logger.debug("User didn't make the first move")
    notify_players(username, points, snake_position, food)
    {:keep_state, state}
  end

  defp update_user_actions(
         %{matrix: {max_x, _}, snake_pos: [{max_x, _} | _], last_action: @move_right} = state
       ),
       do: {:end_game, state}

  defp update_user_actions(%{snake_pos: [{0, _} | _], last_action: @move_left} = state),
    do: {:end_game, state}

  defp update_user_actions(
         %{matrix: {_, max_y}, snake_pos: [{_, max_y} | _], last_action: @move_up} = state
       ),
       do: {:end_game, state}

  defp update_user_actions(%{snake_pos: [{_, 0} | _], last_action: @move_down} = state),
    do: {:end_game, state}

  defp update_user_actions(
         %{
           matrix: {max_x, max_y},
           username: username,
           points: points,
           snake_pos: snake_position,
           food: food,
           last_action: action
         } = state
       ) do
    # Move Snake
    new_snake_position =
      move_snake(snake_position, new_head_position(snake_position, action), food)

    # Check snake not overlapping
    game_state = check_snake_knot(new_snake_position)
    # Check New if new food is needed
    new_food = check_food_was_eaten(max_x, max_y, new_snake_position, food)
    # Increase Points (check if food was eaten)
    add_points =
      case food do
        ^new_food -> @points_by_loop_time
        _ -> @points_by_loop_time + @points_by_eaten_food
      end

    new_points = points + add_points
    # Notify database
    Elisnake.Storage.Game.add_user_points(username, __MODULE__, add_points)
    # Notify web players
    notify_players(username, new_points, new_snake_position, food)

    {game_state, %{state | snake_pos: new_snake_position, food: new_food, points: new_points}}
  end

  # This function moves the whole sneak based on the new head
  # head position and check against the food. If the food is 
  # in the same position of the head, it increments snake size.
  defp move_snake([head | []], new_position, new_position), do: [new_position, head]
  defp move_snake([{_, _} | []], new_position, _), do: [new_position]

  defp move_snake([{px, py} | tail], new_position, new_position),
    do: [new_position, {px, py} | tail]

  defp move_snake([{px, py} | tail], new_position, _),
    do: [new_position, {px, py} | :lists.droplast(tail)]

  # This function moves the Head position based on the action
  defp new_head_position([{x, y} | _], @move_up), do: {x, y + 1}
  defp new_head_position([{x, y} | _], @move_down), do: {x, y - 1}
  defp new_head_position([{x, y} | _], @move_right), do: {x + 1, y}
  defp new_head_position([{x, y} | _], @move_left), do: {x - 1, y}

  # This function moves the whole sneak based on the new head
  # head position and check against the food. If the food is 
  # in the same position of the head, it increments snake size.
  defp check_food_was_eaten(max_x, max_y, [head | _] = snake_position, head),
    do: food_position(max_x, max_y, snake_position)

  defp check_food_was_eaten(_, _, _, food), do: food

  # This function checks if the snake has overlapped
  defp check_snake_knot([head, _, _, _ | tail]) do
    case :lists.member(head, tail) do
      true -> :end_game
      false -> :keep_state
    end
  end

  defp check_snake_knot(_), do: :keep_state

  # Notify subscribed players the game is over with last State  
  defp notify_game_over(%{username: username} = gen_state_data),
    do: gproc_notify(gproc_player_group(username), snake_sm_game_over(gen_state_data))

  # Notify subscribed players the game arena was updated
  defp notify_players(user, points, snake_position, food),
    do: gproc_notify(gproc_player_group(user), snake_sm_update_msg(snake_position, points, food))

  defp snake_sm_update_msg(snake_position, points, food),
    do: {:snake_sm_updated, snake_position, points, food}

  defp snake_sm_game_over(state), do: {:snake_sm_game_over, state}
  # : Gproc groups
  defp gproc_player_group(username), do: {:p, :l, {username, __MODULE__, :notify_on_update}}

  # Gproc function to send messages to the respective pid group
  defp gproc_notify(group, msg) do
    pids = :gproc.lookup_pids(group)

    :lists.foreach(
      fn pid ->
        Logger.debug("Sending PID: #{inspect(pid)}")
        Process.send(pid, msg, [])
      end,
      pids
    )
  end
end
