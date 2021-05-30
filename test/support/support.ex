defmodule Test.Support do
  @max_timeout_feed_snake 10000
  @websocket_timeout 1000
  @move_up :up
  @move_down :down
  @move_right :right
  @move_left :left

  @doc """
    This function try to get the state of a registered server
    
    @param Name Server name
  """
  def try_get_state(name) do
    try do
      :sys.get_state(name)
    catch
      :exit, _ -> :undefined
    end
  end

  @doc """
    This function waits the game over

    @param Timeout Maximum timeout to wait
  """
  def wait_game_over(timeout \\ @max_timeout_feed_snake) do
    receive do
      {:snake_sm_game_over, state} -> {:game_over, state}
    after
      timeout -> :error
    end
  end

  @doc """
    This function move the snake to the required position
    
    @param Pid Process Pid to be changed
    @param Position Position
  """
  def change_snake_position(pid, position) do
    :sys.replace_state(
      pid,
      fn {state_m, gen_server_state} ->
        {state_m, %{gen_server_state | snake_pos: position}}
      end
    )
  end

  @doc """
    This function feeds the snake, e. g., makes the snake
    run throught the whole arena searching for food.
  """
  def feed_snake(username, eaten_food) do
    feed_snake(username, {0, 0}, eaten_food, @max_timeout_feed_snake)
  end

  def feed_snake(_, _, _, timeout) when timeout <= 0, do: :error

  def feed_snake(username, last_snake_position, eaten_food, timeout) do
    # Get Snake State
    {:play, %{matrix: matrix, snake_pos: [head | tail], last_action: action}} =
      Elisnake.GameSm.Sup.children_pid(username)
      |> try_get_state

    # Prepare next Move
    move_snake(username, matrix, last_snake_position, head, action)
    # Check if the snake has reached the expected size
    case length(tail) do
      ^eaten_food ->
        :ok

      _ ->
        :timer.sleep(1)
        feed_snake(username, head, eaten_food, timeout - 1)
    end
  end

  @doc """
    This function executes the following snake moviment
    
    (3,0)|<<<<<<<<<<
    (2,0)|v^>>>>>>>^
    (1,0)|V<<<<<<<<<  
    (0,0)|>>>>>>>>>^
         (0,1) ...
    
    @param User User name
    @param {max_x,max_y} matrix
    @param {px,py} Last head position
    @param {px,py} head position
    @param Action Last action
  """
  def move_snake(_, _, {px, py}, {px, py}, _Action), do: :none

  def move_snake(username, {max_x, max_y}, _, {px, py}, action) do
    case {px, py, action} do
      {^max_x, _, @move_right} -> Elisnake.GameSm.action(username, @move_up)
      {^max_x, _, @move_up} -> Elisnake.GameSm.action(username, @move_left)
      {1, ^max_y, @move_left} -> :none
      {1, ^max_y, @move_up} -> :none
      {1, _, @move_left} -> Elisnake.GameSm.action(username, @move_up)
      {1, _, @move_up} -> Elisnake.GameSm.action(username, @move_right)
      {0, ^max_y, @move_left} -> Elisnake.GameSm.action(username, @move_down)
      {0, 0, @move_down} -> Elisnake.GameSm.action(username, @move_right)
      _ -> :none
    end
  end

  def create_user(user) do
    %{game: :elisnake_sm, user: user} |> Jason.encode!()
  end

  def action_move(user, move) do
    %{game: :elisnake_sm, action: move, user: user} |> Jason.encode!()
  end

  def best_player_msg_response(user, points) do
    %{"best_players" => %{"elisnake_sm" => %{user => points}}} |> Jason.encode!()
  end

  def local_url(port, cmd), do: "http://localhost:" <> to_string(port) <> cmd

  @doc """
    This function opens the websocket in cowboy webserver

    @param host host name
    @param port host port
    @param websocket websocket address
  """
  def open_websocket_connection(host, port, websocket) do
    {:ok, conn_pid} = :gun.open(host |> to_charlist, port, %{protocols: [:http], retry: 0})
    {:ok, _Protocol} = :gun.await_up(conn_pid)
    stream_ref = :gun.ws_upgrade(conn_pid, websocket |> to_charlist, [], %{compress: true})
    # Wait to upgrade connection
    receive do
      {:gun_upgrade, ^conn_pid, ^stream_ref, _, _} ->
        {:ok, {conn_pid, stream_ref}}

      {:gun_ws, ^conn_pid, ^stream_ref, _, _} ->
        {:ok, {conn_pid, stream_ref}}

      msg1 ->
        {:error, {:connection_failed, msg1}}
    after
      @websocket_timeout ->
        {:error, :timeout}
    end
  end

  @doc """
    This function waits a message from websocket
    
    @param ConnPid Host pid
    @param StreamRef Websocket reference
    @param Timeout Timeout to wait for message
  """
  def wait_msg({conn_pid, stream_ref}, timeout \\ @websocket_timeout) do
    # Check that we receive the message sent on timer on init.
    receive do
      {:gun_ws, ^conn_pid, ^stream_ref, msg} ->
        {:ok, msg}
    after
      timeout ->
        {:error, :timeout}
    end
  end

  @doc """
    This function waits until a specific message is received

    @param Msg Message to be listened
    @param Timeout Timeout to wait for message
  """
  def wait_until_msg_is_received(msg, timeout \\ @websocket_timeout) do
    receive do
      {:gun_ws, _, _, ^msg} -> :ok
      _ -> wait_until_msg_is_received(msg, timeout)
    after
      timeout ->
        {:error, :timeout}
    end
  end
end
