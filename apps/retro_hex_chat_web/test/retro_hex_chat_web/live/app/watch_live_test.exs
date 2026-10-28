defmodule RetroHexChatWeb.App.WatchLiveTest do
  @moduledoc """
  Watching a match: open to anybody, an account or not, for a seat offered in
  the open — and a closed door, said plainly, for a session that was not.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.SessionServer
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.Topics
  alias RetroHexChatWeb.LiveMatchPages

  defp registered(prefix) do
    nickname = "#{prefix}#{uid()}" |> String.slice(0, 16)

    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp offered_match do
    host = registered("wh")
    guest = registered("wg")

    {:ok, %{token: token}} =
      Lobby.create_open_session(host.id, metadata: %{"game_id" => "hex_tennis"})

    {:ok, _claimed} = Lobby.claim_open_session(token, guest.id)
    on_exit(fn -> Lobby.close_session(token, host.id, "test_cleanup") end)
    %{token: token, host: host, guest: guest}
  end

  test "a visitor watches, and the canvas follows the games", %{conn: conn} do
    %{token: token, host: host, guest: guest} = offered_match()

    {:ok, view, html} = live(conn, "/watch/#{token}")
    assert html =~ "Waiting for the next game."
    assert html =~ host.nickname
    assert html =~ guest.nickname

    send(view.pid, {:watch_game, %{status: "playing", game_id: "hex_tennis_quick"}})
    html = render(view)

    assert html =~ ~s(phx-hook="SpectateCanvasHook")
    assert html =~ ~s(data-token="#{token}")
    assert html =~ ~s(data-game-id="hex_tennis_quick")
    assert html =~ "Watching Hex Tennis: Quick Match"

    send(view.pid, {:watch_game, %{status: "finished", game_id: "hex_tennis_quick", result: nil}})
    html = render(view)
    refute html =~ "SpectateCanvasHook"
    assert html =~ "Match over"

    # Playing it yourself starts at the game's home, with every way in.
    assert view |> element(~s([data-testid="watch-play"])) |> render() =~
             ~s(href="/games/hex-tennis")
  end

  # The match fills the window: what is said about it is the menu, always
  # there between games and a key away while one is played.
  test "a live match has nothing over it but the key that opens its menu", %{conn: conn} do
    %{token: token} = offered_match()
    {:ok, view, _html} = live(conn, "/watch/#{token}")
    refute has_element?(view, ~s([data-testid="game-stage-menu-key"]))

    send(view.pid, {:watch_game, %{status: "playing", game_id: "hex_tennis_quick"}})
    assert has_element?(view, ~s([data-testid="game-stage-menu-key"]))
    refute has_element?(view, "#watch-stage-menu-show-trigger")

    render_click(view, "watch_menu", %{})
    assert has_element?(view, "#watch-stage-menu-show-trigger")
    assert has_element?(view, ~s([data-testid="watch-resume"]))

    render_click(view, "watch_menu_close", %{})
    refute has_element?(view, "#watch-stage-menu-show-trigger")
  end

  test "it hears the session itself, not a message sent to it by hand", %{conn: conn} do
    %{token: token, host: host, guest: guest} = offered_match()
    {:ok, view, _html} = live(conn, "/watch/#{token}")
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.lobby_watch(token))

    :ok = SessionServer.join(token, host.id)
    :ok = SessionServer.join(token, guest.id)
    :ok = SessionServer.transition(token, :connected)
    :ok = SessionServer.propose_game(token, host.id, host.nickname, "hex_tennis")
    :ok = SessionServer.respond_game(token, guest.id, guest.nickname, true)

    assert_receive {:watch_game, %{status: "playing"}}
    assert render(view) =~ "SpectateCanvasHook"
  end

  test "the page counts itself, and the next one counts too", %{conn: conn} do
    %{token: token} = offered_match()

    {:ok, first, _html} = live(conn, "/watch/#{token}")
    assert first |> element(~s([data-testid="watch-watchers"])) |> render() =~ "1 watching"

    {:ok, _second, _html} = live(build_conn(), "/watch/#{token}")

    # Presence says so on its own; saying it here makes the order certain.
    Phoenix.PubSub.broadcast(RetroHexChat.PubSub, Topics.lobby_watchers(token), %{
      event: "presence_diff"
    })

    assert first |> element(~s([data-testid="watch-watchers"])) |> render() =~ "2 watching"
  end

  test "once a match is over, the other matches being played are offered", %{conn: conn} do
    %{token: token} = offered_match()
    %{token: other, host: host, guest: guest} = offered_match()
    LiveMatchPages.playing([host.nickname, guest.nickname], "hex_pong", other)
    :ok = NickLocales.remember(host.nickname, "ja", store: true)

    {:ok, view, _html} = live(conn, "/watch/#{token}")
    send(view.pid, {:watch_game, %{status: "closed"}})

    html = view |> element(~s([data-testid="watch-others"])) |> render()
    assert html =~ ~s(href="/watch/#{other}")

    text = html |> Floki.parse_fragment!() |> Floki.text() |> String.split() |> Enum.join(" ")

    assert text =~ "#{host.nickname} × #{guest.nickname}" or
             text =~ "#{guest.nickname} × #{host.nickname}"

    # Each player's name after the flag of their language; nobody knows the
    # guest's, so only the host has one.
    assert html
           |> Floki.parse_fragment!()
           |> Floki.find(~s([data-testid="nick-flag"]))
           |> Enum.flat_map(&Floki.attribute(&1, "data-locale")) == ["ja"]
  end

  test "the status bar names the players after the flags of their languages", %{conn: conn} do
    %{token: token, host: host, guest: guest} = offered_match()
    :ok = NickLocales.remember(guest.nickname, "pt_BR", store: true)

    {:ok, _view, html} = live(conn, "/watch/#{token}")

    players = html |> Floki.parse_document!() |> Floki.find(~s([data-testid="match-player"]))

    assert Enum.map(players, &String.trim(Floki.text(&1))) == [
             "#{host.nickname} ×",
             guest.nickname
           ]

    assert players
           |> Enum.map(
             &(&1
               |> Floki.find(~s([data-testid="nick-flag"]))
               |> Floki.attribute("data-locale"))
           ) ==
             [[], ["pt_BR"]]
  end

  test "a session one person invited another to cannot be watched", %{conn: conn} do
    creator = registered("wc")
    peer = registered("wp")
    {:ok, %{token: token}} = Lobby.create_session(creator.id, peer.id)
    on_exit(fn -> Lobby.close_session(token, creator.id, "test_cleanup") end)

    {:ok, _view, html} = live(conn, "/watch/#{token}")
    assert html =~ "This match cannot be watched."
    refute html =~ "SpectateCanvasHook"
  end
end
