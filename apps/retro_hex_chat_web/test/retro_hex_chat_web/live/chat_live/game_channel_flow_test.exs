defmodule RetroHexChatWeb.ChatLive.GameChannelFlowTest do
  @moduledoc """
  A game's channel, as somebody reading it meets it: the strip that names the
  game, the seat it offers, and — for a visitor — the account that pressing it
  asks for.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  import Ecto.Query, only: [from: 2]
  import RetroHexChat.Factory

  alias RetroHexChat.Arcade.SoloSessionServer
  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.Queries, as: ChatQueries
  alias RetroHexChat.Lobby
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.ShareLinks
  alias RetroHexChatWeb.LiveMatchPages

  setup do
    # As `docs/provisioning/en.md` leaves it: registered, announced in.
    insert(:registered_channel, name: "#hex-pong", founder_nickname: "Admin")

    insert_game_announcer(["#hex-pong"])

    on_exit(fn ->
      case ChannelRegistry.lookup("#hex-pong") do
        {:ok, pid} -> ChannelSupervisor.stop_child(pid)
        {:error, :not_found} -> :ok
      end
    end)
  end

  defp register(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp seat_lines do
    "#hex-pong"
    |> ChatQueries.list_messages(limit: 50)
    |> Map.fetch!(:items)
    |> Enum.filter(&(&1.type == "system" and &1.content =~ "/join/"))
  end

  test "Find a partner puts one seat's card in the channel, once", %{conn: conn} do
    nick = register("lfg#{uid()}" |> String.slice(0, 16))

    {:ok, view, _html} =
      live(chat_conn(conn, nick.nickname, pre_identified: true), "/c/hex-pong")

    assert has_element?(view, ~s([data-testid="game-channel-bar"][data-game-id="hex_pong"]))

    view |> element(~s([data-testid="game-channel-lfg"])) |> render_click()
    _ = :sys.get_state(view.pid)

    assert [line] = seat_lines()
    assert line.content =~ "#{nick.nickname} is looking for a partner in Hex Pong"

    slug = line.content |> String.split("/join/") |> List.last() |> String.trim()
    assert {:ok, %{kind: "play", target: target}} = ShareLinks.resolve(slug)
    assert target["game_id"] == "hex_pong"

    {:ok, session} = Lobby.get_session(target["session_token"])
    assert Lobby.open_session?(session)
    assert session.metadata["channel"] == "#hex-pong"

    # The card is still the newest line: a second press brings nothing new.
    view |> element(~s([data-testid="game-channel-lfg"])) |> render_click()
    _ = :sys.get_state(view.pid)
    assert [_still_one] = seat_lines()
  end

  # From the game's home, the same seat — in its channel, which the reader is
  # taken to, so they see the card their press put there.
  test "the game's home finds a partner for a mode in its channel", %{conn: conn} do
    nick = register("home#{uid()}" |> String.slice(0, 16))

    {:ok, view, _html} =
      live(chat_conn(conn, nick.nickname, pre_identified: true), "/games/hex-pong")

    view
    |> element(~s([data-testid="game-way-hex_pong"] [data-testid="game-lfg"]))
    |> render_click()

    assert_patch(view, "/c/hex-pong")
    assert [line] = seat_lines()
    assert line.content =~ "#{nick.nickname} is looking for a partner in Hex Pong"
  end

  # Already in the channel, a press switches to it: joining again would
  # subscribe the chat a second time, and every line would arrive twice.
  test "a press from the home while in the channel subscribes once", %{conn: conn} do
    nick = register("twice#{uid()}" |> String.slice(0, 16))

    {:ok, view, _html} =
      live(chat_conn(conn, nick.nickname, pre_identified: true), "/c/hex-pong")

    subscriptions = fn ->
      RetroHexChat.PubSub
      |> Registry.lookup(RetroHexChat.Topics.channel("#hex-pong"))
      |> Enum.count(fn {pid, _value} -> pid == view.pid end)
    end

    assert subscriptions.() == 1

    render_patch(view, "/games/hex-pong")

    view
    |> element(~s([data-testid="game-way-hex_pong"] [data-testid="game-lfg"]))
    |> render_click()

    assert_patch(view, "/c/hex-pong")
    assert subscriptions.() == 1
  end

  test "the game's home invites a nickname to the game", %{conn: conn} do
    host = register("chal#{uid()}" |> String.slice(0, 16))
    peer = register("peer#{uid()}" |> String.slice(0, 16))
    # The one invited is online, as an invitation needs.
    {:ok, _peer_view, _html} =
      live(chat_conn(build_conn(), peer.nickname, pre_identified: true), "/")

    {:ok, view, _html} =
      live(chat_conn(conn, host.nickname, pre_identified: true), "/games/hex-pong")

    view
    |> element(~s([data-testid="game-challenge-form"]))
    |> render_submit(%{"game" => "hex_pong", "nickname" => peer.nickname})

    # Out to the chat, on the conversation the invitation went to — a private
    # conversation has no address but the chat's own.
    assert_patch(view, "/")

    assert [session] =
             RetroHexChat.Repo.all(
               from(s in RetroHexChat.Lobby.Schema.Session, where: s.creator_id == ^host.id)
             )

    assert session.peer_id == peer.id
    assert Lobby.match_game_id(session) == "hex_pong"
  end

  test "a visitor sees the game's strip, and pressing it asks for an account", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/c/hex-pong")

    assert has_element?(view, ~s([data-testid="game-channel-bar"]))

    view |> element(~s([data-testid="game-channel-lfg"])) |> render_click()

    assert_patch(view, "/connect?return_to=%2Fc%2Fhex-pong&signup=games")
    assert seat_lines() == []
  end

  test "a player in a match in the open can be watched from their nickname's menu",
       %{conn: conn} do
    host = register("host#{uid()}" |> String.slice(0, 16))

    {:ok, %{token: token}} =
      Lobby.create_open_session(host.id, metadata: %{"game_id" => "hex_pong"})

    LiveMatchPages.playing([host.nickname], "hex_pong", token)

    # Closed before the test ends rather than in `on_exit`: by the time an
    # `on_exit` callback runs, the shared sandbox owner may already be gone,
    # and closing a session reads the database.
    try do
      {:ok, view, _html} = live(chat_conn(conn, "viewer#{uid()}"), "/c/hex-pong")

      render_click(view, "nick_right_click", %{"nick" => host.nickname, "x" => 10, "y" => 10})
      assert render(view) =~ "context-menu-item-context_watch"

      render_click(view, "context_watch", %{"nick" => host.nickname})
      assert render(view) =~ "/watch/#{token}"

      # Somebody who is not playing has nothing to watch.
      render_click(view, "nick_right_click", %{"nick" => "idle#{uid()}", "x" => 10, "y" => 10})
      refute render(view) =~ "context-menu-item-context_watch"
    after
      Lobby.close_session(token, host.id, "test_cleanup")
    end
  end

  describe "an arcade game's channel" do
    setup do
      insert(:registered_channel, name: "#doom-shareware", founder_nickname: "Admin")

      insert_game_announcer(["#doom-shareware", "#arcade"], name: "Pixel", nickname: "Pixel")

      on_exit(fn ->
        for name <- ["#doom-shareware", "#arcade"] do
          case ChannelRegistry.lookup(name) do
            {:ok, pid} -> ChannelSupervisor.stop_child(pid)
            {:error, :not_found} -> :ok
          end
        end
      end)
    end

    test "Play opens the arcade on the game, and starting it is said in the room with its card",
         %{conn: conn} do
      nick = register("arc#{uid()}" |> String.slice(0, 16))

      {:ok, view, _html} =
        live(chat_conn(conn, nick.nickname, pre_identified: true), "/c/doom-shareware")

      assert has_element?(
               view,
               ~s([data-testid="game-channel-bar"][data-game-id="doom_shareware"])
             )

      refute has_element?(view, ~s([data-testid="game-channel-lfg"]))

      view |> element(~s([data-testid="game-channel-play"])) |> render_click()
      assert has_element?(view, ~s([data-testid="solo-game-start-doom_shareware"]))

      render_click(view, "arcade_select_game", %{"game-id" => "doom_shareware"})
      %{arcade_session: %{token: token}} = :sys.get_state(view.pid).socket.assigns
      {:ok, _state} = SoloSessionServer.get_state(token)

      assert [line] =
               "#doom-shareware"
               |> ChatQueries.list_messages(limit: 10)
               |> Map.fetch!(:items)
               |> Enum.filter(&(&1.content =~ "started the game"))

      assert line.content == "#{nick.nickname} started the game DOOM: Knee-Deep in the Dead"

      # The line reaches the open room with its card already attached.
      _ = :sys.get_state(view.pid)
      assert render(view) =~ "arcade-play-card-"

      render_click(view, "arcade_leave", %{})
    end

    test "a visitor sees the strip, and Play asks for an account, then lands on the game",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/c/doom-shareware")

      view |> element(~s([data-testid="game-channel-play"])) |> render_click()
      assert_patch(view, "/connect?return_to=%2F%3Farcade%3Ddoom_shareware&signup=games")
    end
  end
end
