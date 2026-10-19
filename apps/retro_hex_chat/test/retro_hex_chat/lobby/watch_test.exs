defmodule RetroHexChat.Lobby.WatchTest do
  @moduledoc """
  Which matches may be watched, and who hosts the one being played.
  """
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.Games.Activity
  alias RetroHexChat.Games.Watchers
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.SessionServer
  alias RetroHexChat.ShareLinks.Card
  alias RetroHexChat.ShareLinks.Schema.Link

  @moduletag :integration

  setup do
    %{
      ana: insert(:registered_nick, nickname: "ana"),
      beto: insert(:registered_nick, nickname: "beto")
    }
  end

  test "a seat offered in the open is a match anybody may watch", %{ana: ana, beto: beto} do
    {:ok, %{session: offered, token: token}} =
      Lobby.create_open_session(ana.id, metadata: %{"game_id" => "hex_pong"})

    on_exit(fn -> Lobby.close_session(token, ana.id, "test_cleanup") end)

    assert offered.metadata["offered"] == true
    assert Lobby.watchable?(offered)

    {:ok, %{session: invited, token: invited_token}} = Lobby.create_session(beto.id, ana.id)
    on_exit(fn -> Lobby.close_session(invited_token, beto.id, "test_cleanup") end)
    refute Lobby.watchable?(invited)

    refute Lobby.watchable?(%{offered | status: "closed"})
  end

  test "only the host of the game in play is its host", %{ana: ana, beto: beto} do
    {:ok, %{token: token}} =
      Lobby.create_open_session(ana.id, metadata: %{"game_id" => "hex_pong"})

    {:ok, _claimed} = Lobby.claim_open_session(token, beto.id)
    on_exit(fn -> Lobby.close_session(token, ana.id, "test_cleanup") end)

    refute Lobby.game_host?(token, ana.id)

    :ok = SessionServer.join(token, ana.id)
    :ok = SessionServer.join(token, beto.id)
    :ok = SessionServer.transition(token, :connected)
    :ok = SessionServer.propose_game(token, ana.id, "ana", "hex_pong")
    :ok = SessionServer.respond_game(token, beto.id, "beto", true)

    assert Lobby.game_host?(token, ana.id)
    refute Lobby.game_host?(token, beto.id)

    # A taken seat's card says the match being played can be watched.
    assert %{state: :ended, reason: :full, watch?: true} =
             Card.of(%Link{
               slug: "s",
               kind: "play",
               target: %{"game_id" => "hex_pong", "session_token" => token}
             })
             |> Map.take([:state, :reason, :watch?])
  end

  # A page is a process of its own: a player's, or somebody watching.
  defp page(fun) do
    test = self()

    pid =
      spawn(fn ->
        fun.()
        send(test, :ready)

        receive do
          :stop -> :ok
        end
      end)

    assert_receive :ready
    on_exit(fn -> send(pid, :stop) end)
    pid
  end

  test "a match in the open is live, with both players and who watches it", %{ana: ana} do
    {:ok, %{token: token}} =
      Lobby.create_open_session(ana.id, metadata: %{"game_id" => "hex_pong"})

    on_exit(fn -> Lobby.close_session(token, ana.id, "test_cleanup") end)
    assert Lobby.watch_token(token) == token

    page(fn -> :ok = Activity.playing("ana", "hex_pong", token) end)
    page(fn -> :ok = Activity.playing("beto", "hex_pong", token) end)

    assert [%{token: ^token, game_id: "hex_pong", players: ["ana", "beto"], watchers: 0}] =
             Activity.live_matches("hex_pong")

    # Each player leads to it, the way a nickname's menu does.
    assert Activity.watch_token("ana") == token
    assert Activity.watch_token("Beto") == token
    assert Activity.watch_token("nobody") == nil

    watcher = page(fn -> :ok = Watchers.watch(token) end)
    page(fn -> :ok = Watchers.watch(token) end)
    assert Watchers.count(token) == 2
    assert [%{watchers: 2}] = Activity.live_matches("hex_pong")

    # A closed tab stops counting on its own.
    ref = Process.monitor(watcher)
    send(watcher, :stop)
    assert_receive {:DOWN, ^ref, :process, _pid, _reason}
    assert eventually(fn -> Watchers.count(token) == 1 end)

    assert Activity.live_matches("hex_tennis") == []
  end

  test "a private match is played, but never live", %{ana: ana, beto: beto} do
    {:ok, %{token: token}} = Lobby.create_session(ana.id, beto.id)
    on_exit(fn -> Lobby.close_session(token, ana.id, "test_cleanup") end)
    assert Lobby.watch_token(token) == nil

    page(fn -> :ok = Activity.playing("ana2", "hex_pong", token) end)

    assert "ana2" in Activity.playing_in("hex_pong")
    refute Enum.any?(Activity.live_matches(), &(&1.token == token))
    assert Activity.watch_token("ana2") == nil
  end

  defp eventually(fun, tries \\ 50) do
    cond do
      fun.() -> true
      tries == 0 -> false
      true -> Process.sleep(10) && eventually(fun, tries - 1)
    end
  end
end
