defmodule ElisnakeTest do
  use ExUnit.Case
  doctest Elisnake

  @app_name :elisnake
  @test_username "unit test username"
  @max_users 50
  @snake_default_position {0, 0}
  @move_up :up
  @move_down :down
  @move_right :right
  @move_left :left

  setup do
    Application.put_env(:elisnake, :port, Enum.random(8000..9000))

    :ok = Application.start(@app_name)

    on_exit(fn ->
      Application.stop(@app_name)
    end)

    :ok
  end

  test "Start/Stop application cheking the supervised server" do
    assert {:ok, _} = Elisnake.GameSm.Sup.create_game(@test_username)

    assert :undefined != Test.Support.try_get_state(Elisnake.GameSm.Sup)

    :ok = Application.stop(@app_name)

    assert :undefined == Test.Support.try_get_state(Elisnake.GameSm.Sup)
  end

  test "Create a supervised game" do
    assert {:ok, _} = Elisnake.GameSm.Sup.create_game(@test_username)
  end

  test "Create a supervised game with the same name" do
    assert {:ok, _} = Elisnake.GameSm.Sup.create_game(@test_username)
    assert {:error, {:already_started, _}} = Elisnake.GameSm.Sup.create_game(@test_username)
  end

  test "Create many users" do
    user_list =
      Enum.map(
        1..@max_users,
        fn user_number ->
          {"username" <> to_string(user_number), __MODULE__, :rand.uniform(5000)}
        end
      )

    # Create users
    user_list
    |> Enum.each(fn {user_id, game, _points} ->
      assert {:ok, 0} = Elisnake.Storage.Game.get_user_points(user_id, game)
    end)

    # Add random points
    user_list
    |> Enum.each(fn {user_id, game, points} ->
      assert :ok = Elisnake.Storage.Game.add_user_points(user_id, game, points)
    end)

    # wait the update
    :timer.sleep(100)

    # Check current values
    user_list
    |> Enum.each(fn {user_id, game, points} ->
      assert {:ok, ^points} = Elisnake.Storage.Game.get_user_points(user_id, game)
    end)
  end

  test "Get the best player" do
    assert {:ok, []} = Elisnake.Storage.Game.get_best_player(__MODULE__)

    assert {:ok, 0} = Elisnake.Storage.Game.get_user_points("user_test0", __MODULE__)
    assert {:ok, 0} = Elisnake.Storage.Game.get_user_points("user_test1", __MODULE__)
    assert {:ok, 0} = Elisnake.Storage.Game.get_user_points("user_test2", __MODULE__)

    # Add points
    assert :ok = Elisnake.Storage.Game.add_user_points("user_test0", __MODULE__, 10)
    assert :ok = Elisnake.Storage.Game.add_user_points("user_test1", __MODULE__, 20)
    assert :ok = Elisnake.Storage.Game.add_user_points("user_test2", __MODULE__, 30)
    # wait the update
    :timer.sleep(100)

    # Check best player
    assert {:ok, [{"user_test2", 30}]} = Elisnake.Storage.Game.get_best_player(__MODULE__)

    # Add points to another player to get more best players
    assert :ok = Elisnake.Storage.Game.add_user_points("user_test1", __MODULE__, 10)
    # wait the update
    :timer.sleep(100)

    # Check best players
    expected_list = :lists.usort([{"user_test2", 30}, {"user_test1", 30}])
    {:ok, read_list} = Elisnake.Storage.Game.get_best_player(__MODULE__)
    assert ^expected_list = :lists.usort(read_list)
  end

  test "Add non existing and get the best player" do
    # Check best player is empty
    assert {:ok, []} = Elisnake.Storage.Game.get_best_player(__MODULE__)

    # Add points
    assert :ok = Elisnake.Storage.Game.add_user_points("user_test0", __MODULE__, 10)
    assert :ok = Elisnake.Storage.Game.add_user_points("user_test1", __MODULE__, 20)
    assert :ok = Elisnake.Storage.Game.add_user_points("user_test2", __MODULE__, 30)
    assert :ok = Elisnake.Storage.Game.add_user_points("user_test2", :my_game, 50)
    # wait the update
    :timer.sleep(100)
    # Check best player
    assert {:ok, [{"user_test2", 50}]} = Elisnake.Storage.Game.get_best_player(:my_game)
  end

  test "Snake join" do
    # Create arena game
    assert {:ok, pid} = Elisnake.GameSm.start_link(@test_username, {10, 10}, 10)

    # Create users, add points, check result
    assert {:join, %{username: @test_username}} = Test.Support.try_get_state(pid)
  end

  test "Snake start ok" do
    # Create arena game
    {:ok, pid} = Elisnake.GameSm.Sup.create_game(@test_username, {10, 10}, 10)

    # Start Game
    assert {:ok, _} = Elisnake.GameSm.start_game(@test_username)

    # Create the state machine
    assert {:play, %{username: @test_username}} = Test.Support.try_get_state(pid)
  end

  test "Snake check idle :ok" do
    # Create arena game
    {:ok, pid} = Elisnake.GameSm.Sup.create_game(@test_username, {10, 10}, 10)

    # Start Game
    assert {:ok, _} = Elisnake.GameSm.start_game(@test_username)

    # Sleep to allow the loop time to occur
    :timer.sleep(100)

    # Create the state machine
    assert {:play, %{last_action: :idle}} = Test.Support.try_get_state(pid)
  end

  test "Snake already created" do
    # Create arena game
    {:ok, _} = Elisnake.GameSm.Sup.create_game(@test_username, {10, 10}, 10)

    # Try to create same game with the same user
    assert {:error, {:already_started, _}} =
             Elisnake.GameSm.Sup.create_game(@test_username, {10, 10}, 10)
  end

  %{
    1 => %{direction: @move_up},
    2 => %{direction: @move_down},
    3 => %{direction: @move_left},
    4 => %{direction: @move_right}
  }
  |> Enum.each(fn {element, %{direction: direction}} ->
    test "Test:#{element} - Snake go #{direction}" do
      # Create arena game
      {:ok, _} = Elisnake.GameSm.Sup.create_game(@test_username, {10, 10}, 1)
      # Start Game
      Elisnake.GameSm.start_game(@test_username)
      # Move
      Elisnake.GameSm.action(@test_username, unquote(direction))
      # Wait for the game over state and check the last state
      direction = unquote(direction)
      assert {:game_over, %{last_action: ^direction}} = Test.Support.wait_game_over()
    end
  end)

  test "Snake seek food" do
    {:ok, pid} = Elisnake.GameSm.Sup.create_game(@test_username, {5, 5}, 2)
    # Put Snake in the default position
    Test.Support.change_snake_position(pid, [@snake_default_position])
    # Start Game
    Elisnake.GameSm.start_game(@test_username)
    Elisnake.GameSm.action(@test_username, @move_right)
    # Wait the snake to be fed
    assert :ok = Test.Support.feed_snake(@test_username, 20)
  end

  %{
    1 => %{next_direction: @move_down, previous_direction: @move_up},
    2 => %{next_direction: @move_right, previous_direction: @move_left},
    3 => %{next_direction: @move_left, previous_direction: @move_right},
    4 => %{next_direction: @move_up, previous_direction: @move_down}
  }
  |> Enum.each(fn {element,
                   %{next_direction: next_direction, previous_direction: previous_direction}} ->
    test "Test:#{element} - Snake reverse not allowed previous: #{previous_direction} next_direction: #{
           next_direction
         }" do
      {:ok, pid} = Elisnake.GameSm.Sup.create_game(@test_username, {10, 10}, 1)
      # Insert snake bigger then 2 positions to avoid reverse moviment
      Test.Support.change_snake_position(pid, [{5, 4}, {5, 3}])
      # Start Game
      next_direction = unquote(next_direction)
      previous_direction = unquote(previous_direction)
      Elisnake.GameSm.start_game(@test_username)
      Elisnake.GameSm.action(@test_username, previous_direction)
      Elisnake.GameSm.action(@test_username, next_direction)
      # Wait for the game over state and check the last state
      assert {:game_over, %{last_action: ^previous_direction}} = Test.Support.wait_game_over()
    end
  end)

  test "Snake knot game over" do
    {:ok, pid} = Elisnake.GameSm.Sup.create_game(@test_username, {20, 20}, 1)
    # Insert snake bigger then 2 positions to avoid reverse moviment
    Test.Support.change_snake_position(pid, [
      {2, 5},
      {2, 4},
      {2, 3},
      {2, 2},
      {2, 1},
      {3, 1},
      {3, 2},
      {3, 3},
      {3, 4},
      {3, 5},
      {3, 6}
    ])

    # Start Game
    Elisnake.GameSm.start_game(@test_username)
    Elisnake.GameSm.action(@test_username, @move_right)
    # Wait for the game over state and check the last state
    assert {:game_over, %{last_action: @move_right}} = Test.Support.wait_game_over()
  end

  test "snake another observer" do
    {:ok, pid} = Elisnake.GameSm.Sup.create_game(@test_username, {10, 10}, 1)
    # Insert snake bigger then 2 positions to avoid reverse moviment
    Test.Support.change_snake_position(pid, [{3, 3}, {4, 3}])
    # Start Game
    Elisnake.GameSm.start_game(@test_username)
    # Spawn an observer process
    pid =
      spawn_link(fn ->
        Elisnake.GameSm.start_game(@test_username)

        receive do
          _ -> :timer.sleep(10000)
        end
      end)

    # Sleep to allow the previous process to register
    :timer.sleep(100)
    # Check the both Pids are registered
    self = self()

    assert [^self, ^pid] =
             :gproc.lookup_pids({:p, :l, {@test_username, Elisnake.GameSm, :notify_on_update}})
  end

  test "snake crash join" do
    {:ok, pid} = Elisnake.GameSm.Sup.create_game(@test_username, {10, 10}, 1)
    # Insert Snake in a specific position
    Test.Support.change_snake_position(pid, [{1, 1}])
    # Send Kill signal to the snake game
    Process.exit(pid, :kill)
    # Check new process was started
    :timer.sleep(10)
    # Check the both Pids are different and the state is still in join
    assert pid != @test_username |> Elisnake.GameSm.Sup.children_pid()

    assert {:join, _} =
             @test_username |> Elisnake.GameSm.Sup.children_pid() |> Test.Support.try_get_state()
  end

  test "crash recovery" do
    {:ok, pid} = Elisnake.GameSm.Sup.create_game(@test_username, {10, 10}, 1)
    # Insert Snake in a specific position
    Test.Support.change_snake_position(pid, [{1, 1}])
    # Send Kill signal to the snake game
    :gen_statem.cast(pid, {:none})
    # Check new process was started
    :timer.sleep(100)
    # Check the both Pids are different and the state is still in join
    assert pid != @test_username |> Elisnake.GameSm.Sup.children_pid()

    assert {:join, _} =
             @test_username |> Elisnake.GameSm.Sup.children_pid() |> Test.Support.try_get_state()
  end

  test "crash recovery state play" do
    {:ok, pid} = Elisnake.GameSm.Sup.create_game(@test_username, {10, 10}, 1)
    # Insert Snake in a specific position
    Test.Support.change_snake_position(pid, [{1, 1}])
    # Play Game
    Elisnake.GameSm.start_game(@test_username)
    # Send Kill signal to the snake game
    :gen_statem.cast(pid, {:none})
    # Check new process was started
    :timer.sleep(100)
    # Check the both Pids are different and the state is still in play
    assert pid != @test_username |> Elisnake.GameSm.Sup.children_pid()

    assert {:play, _} =
             @test_username |> Elisnake.GameSm.Sup.children_pid() |> Test.Support.try_get_state()
  end
end
