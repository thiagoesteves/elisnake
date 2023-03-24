defmodule ElisnakeWebTest do
  use ExUnit.Case
  doctest Elisnake

  @app_name :elisnake
  @move_left :left
  @index_html_file "priv/index.html"
  @default_player "Thiago Esteves"
  @initial_message "Elisnake is alive!"
  @game_over_msg {:close, 1000, "Game Over"}
  @snake_best_player "{\"request\":\"get_best_player\",\"game\":\"elisnake_sm\"}"
  @best_player_msg_response_empty "{\"best_players\":{\"elisnake_sm\":{}}}"

  setup do
    port = Enum.random(8000..9000)
    Application.put_env(:elisnake, :port, port)

    :ok = Application.start(@app_name)

    Application.ensure_all_started(:gun)

    on_exit(fn ->
      Application.stop(@app_name)
    end)

    %{port: port}
  end

  test "Snake web index html ok", %{port: port} do
    {:ok, response} = Test.Support.local_url(port, "/") |> HTTPoison.get()

    file = File.read!(@index_html_file)

    assert file == response.body
  end

  test "Snake websocket connect ok", %{port: port} do
    # Connect with the application and open the websockets
    {:ok, {conn_pid, stream_ref}} =
      Test.Support.open_websocket_connection("localhost", port, "/websocket")

    # Expect the init  message
    assert {:ok, {:text, @initial_message}} = Test.Support.wait_msg({conn_pid, stream_ref})
    # Shutdown
    :gun.shutdown(conn_pid)
  end

  @tag capture_log: true
  test "Snake websocket play ok", %{port: port} do
    # Connect with the application and open the websockets
    {:ok, {conn_pid, stream_ref}} =
      Test.Support.open_websocket_connection("localhost", port, "/websocket")

    # Expect the init  message
    {:ok, {:text, @initial_message}} = Test.Support.wait_msg({conn_pid, stream_ref})
    # Create snake game for the default player
    :gun.ws_send(conn_pid, stream_ref, {:text, Test.Support.create_user(@default_player)})
    # Wait to receive any information from the game
    assert {:ok, {:text, _}} = Test.Support.wait_msg({conn_pid, stream_ref})
    # Check the game is ready to play
    assert {:play, %{username: @default_player}} =
             @default_player
             |> Elisnake.GameSm.Sup.children_pid()
             |> Test.Support.try_get_state()

    # Shutdown
    :gun.shutdown(conn_pid)
  end

  test "Snake websocket game over ok", %{port: port} do
    # Connect with the application and open the websockets
    {:ok, {conn_pid, stream_ref}} =
      Test.Support.open_websocket_connection("localhost", port, "/websocket")

    # Expect the init  message
    {:ok, {:text, @initial_message}} = Test.Support.wait_msg({conn_pid, stream_ref})
    # Create snake game for the default player
    :gun.ws_send(conn_pid, stream_ref, {:text, Test.Support.create_user(@default_player)})
    # Wait to receive any information from the game
    assert {:ok, {:text, _}} = Test.Support.wait_msg({conn_pid, stream_ref})
    # Check the game is ready to play
    assert {:play, %{username: @default_player}} =
             @default_player
             |> Elisnake.GameSm.Sup.children_pid()
             |> Test.Support.try_get_state()

    # Start the moviment
    :gun.ws_send(
      conn_pid,
      stream_ref,
      {:text, Test.Support.action_move(@default_player, @move_left)}
    )

    # Check game over message was received
    assert :ok = Test.Support.wait_until_msg_is_received(@game_over_msg)
    # Shutdown
    :gun.shutdown(conn_pid)
  end

  test "Snake websocket game over ok (restart same user)", %{port: port} do
    # Connect with the application and open the websockets
    {:ok, {conn_pid, stream_ref}} =
      Test.Support.open_websocket_connection("localhost", port, "/websocket")

    # Expect the init  message
    {:ok, {:text, @initial_message}} = Test.Support.wait_msg({conn_pid, stream_ref})

    # Connect again with the same user
    {:ok, {conn_pid2, stream_ref2}} =
      Test.Support.open_websocket_connection("localhost", port, "/websocket")

    # Expect the init  message
    {:ok, {:text, @initial_message}} = Test.Support.wait_msg({conn_pid2, stream_ref2})

    # Create snake game for the default player
    :gun.ws_send(conn_pid, stream_ref, {:text, Test.Support.create_user(@default_player)})
    # Wait to receive any information from the game
    assert {:ok, {:text, _}} = Test.Support.wait_msg({conn_pid, stream_ref})
    # Check the game is ready to play
    assert {:play, %{username: @default_player}} =
             @default_player
             |> Elisnake.GameSm.Sup.children_pid()
             |> Test.Support.try_get_state()

    # Start the moviment
    :gun.ws_send(
      conn_pid,
      stream_ref,
      {:text, Test.Support.action_move(@default_player, @move_left)}
    )

    # Check game over message was received
    assert :ok = Test.Support.wait_until_msg_is_received(@game_over_msg)

    # Create snake game for the same previous user
    :gun.ws_send(conn_pid2, stream_ref2, {:text, Test.Support.create_user(@default_player)})
    # Wait to receive any information from the game
    assert {:ok, {:text, _}} = Test.Support.wait_msg({conn_pid2, stream_ref2})
    # Check the game is ready to play
    assert {:play, %{username: @default_player}} =
             @default_player
             |> Elisnake.GameSm.Sup.children_pid()
             |> Test.Support.try_get_state()

    # Start the moviment
    :gun.ws_send(
      conn_pid2,
      stream_ref2,
      {:text, Test.Support.action_move(@default_player, @move_left)}
    )

    # Check game over message was received
    assert :ok = Test.Support.wait_until_msg_is_received(@game_over_msg)
    # Shutdown
    :gun.shutdown(conn_pid)
    :gun.shutdown(conn_pid2)
  end

  test "Snake websocket best player ok", %{port: port} do
    # Connect with the application and open the websockets
    {:ok, {conn_pid, stream_ref}} =
      Test.Support.open_websocket_connection("localhost", port, "/websocket")

    # Expect the init  message
    {:ok, {:text, @initial_message}} = Test.Support.wait_msg({conn_pid, stream_ref})
    # Request Best Player
    :gun.ws_send(conn_pid, stream_ref, {:text, @snake_best_player})
    # No best players
    assert {:ok, {:text, @best_player_msg_response_empty}} =
             Test.Support.wait_msg({conn_pid, stream_ref})

    # Add Player in Database
    Elisnake.Storage.Game.add_user_points(@default_player, Elisnake.GameSm, 10)
    # Request Best Player
    :gun.ws_send(conn_pid, stream_ref, {:text, @snake_best_player})
    # Check new best Player
    player = Test.Support.best_player_msg_response(@default_player, 10)
    assert {:ok, {:text, ^player}} = Test.Support.wait_msg({conn_pid, stream_ref})

    # Shutdown
    :gun.shutdown(conn_pid)
  end

  test "Snake websocket connect same user ok", %{port: port} do
    # Connect with the application and open the websockets
    {:ok, {conn_pid, stream_ref}} =
      Test.Support.open_websocket_connection("localhost", port, "/websocket")

    # Expect the init  message
    {:ok, {:text, @initial_message}} = Test.Support.wait_msg({conn_pid, stream_ref})
    # Create snake game for the default player
    :gun.ws_send(conn_pid, stream_ref, {:text, Test.Support.create_user(@default_player)})
    # Wait to receive any information from the game
    assert {:ok, {:text, _}} = Test.Support.wait_msg({conn_pid, stream_ref})

    # Check the game is ready to play
    assert {:play, %{username: @default_player}} =
             @default_player
             |> Elisnake.GameSm.Sup.children_pid()
             |> Test.Support.try_get_state()

    # Connect another client to the same user
    {:ok, {conn_pid2, stream_ref2}} =
      Test.Support.open_websocket_connection("localhost", port, "/websocket")

    # Expect the init  message
    {:ok, {:text, @initial_message}} = Test.Support.wait_msg({conn_pid2, stream_ref2})
    # Create snake game for the default player again
    :gun.ws_send(conn_pid2, stream_ref2, {:text, Test.Support.create_user(@default_player)})
    # Wait to receive any information from the game
    assert {:ok, {:text, _}} = Test.Support.wait_msg({conn_pid2, stream_ref2})

    # Check there are two Pids registered
    assert [_, _] =
             :gproc.lookup_pids({:p, :l, {@default_player, Elisnake.GameSm, :notify_on_update}})

    # Start the moviment
    :gun.ws_send(
      conn_pid,
      stream_ref,
      {:text, Test.Support.action_move(@default_player, @move_left)}
    )

    # Check game over message was received 2 times (Two clients were registered)
    assert :ok = Test.Support.wait_until_msg_is_received(@game_over_msg)
    assert :ok = Test.Support.wait_until_msg_is_received(@game_over_msg)
    # Shutdown
    :gun.shutdown(conn_pid)
    :gun.shutdown(conn_pid2)
  end
end
