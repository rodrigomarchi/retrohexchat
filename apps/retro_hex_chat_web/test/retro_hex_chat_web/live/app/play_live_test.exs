defmodule RetroHexChatWeb.App.PlayLiveTest do
  @moduledoc """
  The first surface that is not the chat, and the coexistence it has to prove.

  Most of what is asserted here is about `Live.Surface` rather than about games:
  a second tab of this app must survive the chat being taken over, must not
  survive a ban, and must not touch the presence or the channel membership that
  belong to the chat session.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Admin.ServerBans
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.SessionControl
  alias RetroHexChat.Topics

  describe "who may open it" do
    test "no session goes to connect", %{conn: conn} do
      assert redirected_to_connect(live(conn, ~p"/play"))
    end

    test "a nickname the validator refuses goes to connect", %{conn: conn} do
      assert redirected_to_connect(conn |> chat_conn("not a nick") |> live(~p"/play"))
    end

    test "a banned nickname goes to connect saying so", %{conn: conn} do
      nick = "Ban#{uid()}"
      {:ok, _msg} = ServerBans.ban(nick, "admin", "testing", nil)

      assert {:error, {_kind, %{to: to}}} = conn |> chat_conn(nick) |> live(~p"/play")
      assert to =~ "/connect"
      assert to =~ "banned"
    end

    test "a valid session gets the library", %{conn: conn} do
      {:ok, _view, html} = conn |> chat_conn("Play#{uid()}") |> live(~p"/play")

      assert html =~ "retro-games-panel"
    end
  end

  describe "coexistence with the chat" do
    # The whole point of the surface. ChatLive announces a takeover on the
    # person's inbox when it mounts; a surface must not, or opening a game
    # would end the chat that opened it.
    test "opening it does not announce a takeover", %{conn: conn} do
      nick = "Coex#{uid()}"
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(nick))

      {:ok, _view, _html} = conn |> chat_conn(nick) |> live(~p"/play")

      refute_receive {:force_disconnect, _payload}
    end

    # Global presence is owned by the chat session and released by its
    # terminate. A surface that tracked would make closing the game tab look
    # like going offline.
    test "opening it does not put the person online", %{conn: conn} do
      nick = "Pres#{uid()}"

      {:ok, _view, _html} = conn |> chat_conn(nick) |> live(~p"/play")

      refute Tracker.online?(Topics.presence(), nick)
    end

    test "a chat takeover leaves it running", %{conn: conn} do
      nick = "Keep#{uid()}"
      {:ok, view, _html} = conn |> chat_conn(nick) |> live(~p"/play")

      SessionControl.disconnect(nick, %{reason: "another window"}, :chat)

      # render/1 is a synchronous round trip, and the broadcast queued before
      # it — so if the surface were going to act on that message, it already
      # would have. No sleep, no retry.
      assert render(view) =~ "retro-games-panel"
    end

    test "a ban ends it", %{conn: conn} do
      nick = "Gone#{uid()}"
      {:ok, view, _html} = conn |> chat_conn(nick) |> live(~p"/play")

      SessionControl.disconnect(nick, %{reason: "Server banned"}, :all)

      assert {to, _flash} = assert_redirect(view)
      assert to =~ "/chat/session/clear"
      assert to =~ "Server+banned"
    end
  end

  describe "choosing a game" do
    test "a known game in the path opens it", %{conn: conn} do
      {:ok, _view, html} = conn |> chat_conn("Pick#{uid()}") |> live(~p"/play/hex_pong")

      assert html =~ "RetroGameCanvasHook"
    end

    test "an unknown game falls back to the library", %{conn: conn} do
      {:ok, _view, html} = conn |> chat_conn("Miss#{uid()}") |> live(~p"/play/not_a_game")

      assert html =~ "retro-games-panel"
      refute html =~ "RetroGameCanvasHook"
    end
  end

  describe "sharing a game" do
    test "a registered nickname mints a link that resolves back to the game", %{conn: conn} do
      nick = "Share#{uid()}"
      {:ok, _} = register(nick)

      {:ok, view, _html} = conn |> chat_conn(nick) |> live(~p"/play/hex_pong")

      refute render(view) =~ "share-url"
      html = view |> element(~s([data-testid="share-create"])) |> render_click()

      assert [url] =
               html
               |> Floki.parse_fragment!()
               |> Floki.find(~s([data-testid="share-url"]))
               |> Floki.attribute("value")

      # The loop the whole wave exists for: what the surface minted is what the
      # public card resolves, and it points back at the game it was minted from.
      slug = url |> String.split("/join/") |> List.last()
      assert {:ok, resolution} = RetroHexChat.ShareLinks.resolve(slug)
      assert resolution.kind == "play"
      assert resolution.target == %{"game_id" => "hex_pong"}
      assert resolution.live?
    end

    # Pressing Share twice must not mint two live addresses, which would make
    # revoking one of them a half-answer.
    test "pressing it again hands back the address you already have", %{conn: conn} do
      nick = "Twice#{uid()}"
      {:ok, _} = register(nick)

      {:ok, view, _html} = conn |> chat_conn(nick) |> live(~p"/play/hex_pong")

      first = share_url(view)
      # Revoking is the only way to a different one, so a second press with the
      # link still open has to be the same link.
      assert share_url_after_reopen(conn, nick) == first
    end

    test "revoking closes the address and leaves the game alone", %{conn: conn} do
      nick = "Revoke#{uid()}"
      {:ok, _} = register(nick)

      {:ok, view, _html} = conn |> chat_conn(nick) |> live(~p"/play/hex_pong")

      url = share_url(view)
      slug = url |> String.split("/join/") |> List.last()
      assert {:ok, %{live?: true}} = RetroHexChat.ShareLinks.describe(slug)

      html = view |> element(~s([data-testid="share-revoke"])) |> render_click()

      # The bar goes back to offering a fresh one, and the old address is closed
      # rather than merely hidden.
      assert html =~ "share-create"
      refute html =~ "share-url"
      assert {:error, :revoked} = RetroHexChat.ShareLinks.describe(slug)

      # The game is untouched: it is still there to be shared again.
      assert render(view) =~ "hex_pong"
    end

    # Pressing Share is a request to see the address, so the window opens by
    # itself. Arriving on a surface that already has a link is not: walking into
    # a room you shared earlier must not put the address in front of you.
    test "the window opens on the press that mints, and not on arrival", %{conn: conn} do
      nick = "Auto#{uid()}"
      {:ok, _} = register(nick)

      {:ok, view, _html} = conn |> chat_conn(nick) |> live(~p"/play/hex_pong")

      html = view |> element(~s([data-testid="share-create"])) |> render_click()
      assert html =~ ~s(data-testid="share-url")
      refute open_dialog?(html)

      # Closing it leaves the control saying there is a link, and reopening is
      # the reader's move rather than the page's.
      reopened = view |> element(~s([data-testid="share-close"])) |> render_click()
      assert reopened =~ ~s(data-testid="share-open")
      assert open_dialog?(reopened)
    end

    test "a guest is told why they cannot", %{conn: conn} do
      {:ok, view, _html} = conn |> chat_conn("Guest#{uid()}") |> live(~p"/play/hex_pong")

      assert render(view) =~ "share-create"
      assert view |> element(~s([data-testid="share-create"])) |> render() =~ "disabled"
    end

    test "there is nothing to share from the library", %{conn: conn} do
      {:ok, _view, html} = conn |> chat_conn("Lib#{uid()}") |> live(~p"/play")

      refute html =~ "share-bar"
    end
  end

  defp register(nickname) do
    RetroHexChat.Repo.insert(%RetroHexChat.Services.RegisteredNick{
      nickname: nickname,
      password_hash: "x",
      registered_at: DateTime.utc_now(),
      last_seen_at: DateTime.utc_now()
    })
  end

  defp redirected_to_connect({:error, {_kind, %{to: to}}}), do: to == "/connect"
  defp redirected_to_connect(_other), do: false

  # The dialog wrapper carries `hidden` while it is closed; the surrounding
  # markup is identical either way, so that class is the whole difference.
  defp open_dialog?(html) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(~s([data-testid="share-game-dialog"] > div))
    |> Floki.attribute("class")
    |> Enum.any?(&String.contains?(&1, "hidden"))
  end

  defp share_url(view) do
    [url] =
      view
      |> element(~s([data-testid="share-create"]))
      |> render_click()
      |> Floki.parse_fragment!()
      |> Floki.find(~s([data-testid="share-url"]))
      |> Floki.attribute("value")

    url
  end

  # A second press from a page that has forgotten the address: the assign is
  # gone, so only the database can hand the same link back.
  defp share_url_after_reopen(conn, nick) do
    {:ok, view, _html} = conn |> chat_conn(nick) |> live(~p"/play/hex_pong")
    share_url(view)
  end
end
