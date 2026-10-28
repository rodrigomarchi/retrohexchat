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
  alias RetroHexChat.Games.Activity
  alias RetroHexChat.Nickname
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.SessionControl
  alias RetroHexChat.Topics
  alias RetroHexChatWeb.App.Paths

  describe "who may open it" do
    test "no session lands in the chat, asked to sign in for games and brought back", %{
      conn: conn
    } do
      assert {:error, {_kind, %{to: to}}} = live(conn, ~p"/play/tetris")
      assert to == Paths.visitor_sign_in_path(:games, "/play/tetris")
    end

    test "a nickname the validator refuses is a visitor", %{conn: conn} do
      assert {:error, {_kind, %{to: to}}} =
               conn |> chat_conn("not a nick") |> live(~p"/play/hex_pong")

      assert to == Paths.visitor_sign_in_path(:games, "/play/hex_pong")
    end

    # Nothing to play names nothing that needs an account: the catalogue it
    # points at is public.
    test "a visitor at /play with no game reads the catalogue, unasked", %{conn: conn} do
      assert {:error, {_kind, %{to: "/games"}}} = live(conn, ~p"/play")
    end

    test "a banned nickname goes to connect saying so", %{conn: conn} do
      nick = "Ban#{uid()}"
      {:ok, _msg} = ServerBans.ban(nick, "admin", "testing", nil)

      assert {:error, {_kind, %{to: to}}} = conn |> chat_conn(nick) |> live(~p"/play")
      assert to =~ "/connect"
      assert to =~ "banned"
    end

    # One game per page: the games are chosen in the catalogue.
    test "a valid session with no game in the address is sent to the catalogue", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/games"}}} =
               conn |> chat_conn("Play#{uid()}") |> live(~p"/play")
    end
  end

  describe "coexistence with the chat" do
    # The whole point of the surface. ChatLive announces a takeover on the
    # person's inbox when it mounts; a surface must not, or opening a game
    # would end the chat that opened it.
    test "opening it does not announce a takeover", %{conn: conn} do
      nick = "Coex#{uid()}"
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(nick))

      {:ok, _view, _html} = conn |> chat_conn(nick) |> live(~p"/play/hex_pong")

      refute_receive {:force_disconnect, _payload}
    end

    # Global presence is owned by the chat session and released by its
    # terminate. A surface that tracked would make closing the game tab look
    # like going offline.
    test "opening it does not put the person online", %{conn: conn} do
      nick = "Pres#{uid()}"

      {:ok, _view, _html} = conn |> chat_conn(nick) |> live(~p"/play/hex_pong")

      refute Tracker.online?(Topics.presence(), nick)
    end

    test "a chat takeover leaves it running", %{conn: conn} do
      nick = "Keep#{uid()}"
      {:ok, view, _html} = conn |> chat_conn(nick) |> live(~p"/play/hex_pong")

      SessionControl.disconnect(nick, %{reason: "another window"}, :chat)

      # render/1 is a synchronous round trip, and the broadcast queued before
      # it — so if the surface were going to act on that message, it already
      # would have. No sleep, no retry.
      assert render(view) =~ "retro-games-panel"
    end

    test "a ban ends it", %{conn: conn} do
      nick = "Gone#{uid()}"
      {:ok, view, _html} = conn |> chat_conn(nick) |> live(~p"/play/hex_pong")

      SessionControl.disconnect(nick, %{reason: "Server banned"}, :all)

      assert {to, _flash} = assert_redirect(view)
      assert to =~ "/chat/session/clear"
      assert to =~ "Server+banned"
    end
  end

  describe "choosing a game" do
    test "a known game in the path opens it", %{conn: conn} do
      {:ok, view, html} = conn |> chat_conn("Pick#{uid()}") |> live(~p"/play/hex_tennis_quick")

      assert html =~ "RetroGameCanvasHook"

      # The rest of the game is at its home and in its channel — a mode's,
      # its game's.
      assert view |> element(~s([data-testid="play-game-home"])) |> render() =~
               ~s(href="/games/hex-tennis")

      assert view |> element(~s([data-testid="play-game-channel"])) |> render() =~
               ~s(href="/c/hex-tennis")
    end

    # End mid-match asks the canvas to end the match as it stands; the result it
    # reports is the match's end, like any other.
    test "ending a match mid-play asks the canvas for the match as it stands", %{conn: conn} do
      nick = "End#{uid()}"
      {:ok, view, _html} = conn |> chat_conn(nick) |> live(~p"/play/hex_pong")

      render_hook(view, "retro_game_canvas_ready", %{"game_id" => "hex_pong"})
      render_click(view, "retro_games_start_ai", %{})
      assert Map.has_key?(Activity.now(), Nickname.key(nick))

      # End is in the menu, over the match it holds.
      render_hook(view, "retro_games_menu", %{"game_id" => "hex_pong"})
      render_click(view, "retro_games_end", %{})
      assert_push_event(view, "retro_game_quit", %{game_id: "hex_pong"})
      assert has_element?(view, ~s([data-testid="retro-game-end-match"]))

      html =
        render_hook(view, "retro_game_result", %{
          "game_id" => "hex_pong",
          "score" => %{"p1" => 2, "p2" => 1},
          "ended_early" => true
        })

      refute Map.has_key?(Activity.now(), Nickname.key(nick))
      # The score as it stood, and no verdict: a match ended early is no win.
      assert html =~ "You 2 x 1 AI"
      refute html =~ "You won"
      assert html =~ "retro-game-ended-early"
    end

    # A canvas with no match left to end says so, and the game is made ready
    # for another, as a match nobody played.
    test "a canvas with nothing to end leaves the game ready", %{conn: conn} do
      nick = "Stop#{uid()}"
      {:ok, view, _html} = conn |> chat_conn(nick) |> live(~p"/play/hex_pong")

      render_hook(view, "retro_game_canvas_ready", %{"game_id" => "hex_pong"})
      render_click(view, "retro_games_start_ai", %{})
      render_click(view, "retro_games_end", %{})
      render_hook(view, "retro_game_stopped", %{"game_id" => "hex_pong"})

      assert_push_event(view, "retro_game_stop", %{game_id: "hex_pong"})
      refute Map.has_key?(Activity.now(), Nickname.key(nick))

      # The canvas loads a fresh engine and says so before another match.
      assert has_element?(view, ~s([data-testid="retro-game-start-disabled"]))
      render_hook(view, "retro_game_canvas_ready", %{"game_id" => "hex_pong"})
      assert has_element?(view, ~s([data-testid="retro-game-start-ai"]))
    end

    # Esc, the corner key, or the tab put away: the match holds under its menu,
    # and Continue (or Esc again) goes on from where it stood.
    test "the menu holds the match, and Continue goes on with it", %{conn: conn} do
      {:ok, view, _html} = conn |> chat_conn("Hold#{uid()}") |> live(~p"/play/hex_pong")

      render_hook(view, "retro_game_canvas_ready", %{"game_id" => "hex_pong"})
      render_click(view, "retro_games_start_ai", %{})
      refute has_element?(view, ~s([data-testid="retro-game-paused"]))

      render_hook(view, "retro_games_menu", %{"game_id" => "hex_pong"})
      assert_push_event(view, "retro_game_pause", %{game_id: "hex_pong"})
      assert has_element?(view, ~s([data-testid="retro-game-paused"]))

      render_click(view, "retro_games_resume", %{})
      assert_push_event(view, "retro_game_resume", %{game_id: "hex_pong"})
      refute has_element?(view, ~s([data-testid="retro-game-paused"]))
    end

    test "there is no match to hold before one starts", %{conn: conn} do
      {:ok, view, _html} = conn |> chat_conn("NoHold#{uid()}") |> live(~p"/play/hex_pong")

      render_hook(view, "retro_games_menu", %{"game_id" => "hex_pong"})
      refute_push_event(view, "retro_game_pause", %{})
      assert has_element?(view, ~s([data-testid="retro-game-start-disabled"]))
    end

    # The canvas stays through the result; Again loads a fresh engine on it.
    test "Again after a result loads a fresh engine and waits for it", %{conn: conn} do
      {:ok, view, _html} = conn |> chat_conn("Again#{uid()}") |> live(~p"/play/hex_pong")

      render_hook(view, "retro_game_canvas_ready", %{"game_id" => "hex_pong"})
      render_click(view, "retro_games_start_ai", %{})

      render_hook(view, "retro_game_result", %{
        "game_id" => "hex_pong",
        "score" => %{"p1" => 11, "p2" => 4}
      })

      assert has_element?(view, ~s([data-testid="retro-game-canvas-hex_pong"]))
      render_click(view, "retro_games_play_again", %{})
      assert_push_event(view, "retro_game_stop", %{game_id: "hex_pong"})
      assert has_element?(view, ~s([data-testid="retro-game-start-disabled"]))
      render_hook(view, "retro_game_canvas_ready", %{"game_id" => "hex_pong"})
      assert has_element?(view, ~s([data-testid="retro-game-start-ai"]))
    end

    test "a one-player game offers no match with somebody, nor opens one", %{conn: conn} do
      nick = "Alone#{uid()}"
      {:ok, _} = register(nick)
      conn = chat_conn(conn, nick, pre_identified: true)

      {:ok, view, _html} = live(conn, ~p"/play/hex_jungle")
      refute has_element?(view, ~s([data-testid="play-create-match"]))

      {:ok, view, _html} = live(conn, ~p"/play/hex_jungle?match=new")
      refute has_element?(view, ~s([data-testid="play-match-error"]))
      assert has_element?(view, ~s([data-testid="retro-game-session-hex_jungle"]))
      # A room would navigate the page away; it stays on the game.
      assert render_click(view, "create_match", %{}) =~ "retro-game-session-hex_jungle"
    end

    test "an unknown game is sent to the catalogue", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/games"}}} =
               conn |> chat_conn("Miss#{uid()}") |> live(~p"/play/not_a_game")
    end
  end

  describe "a finished match" do
    setup do
      # A match in a test lasts as long as a render round trip.
      Application.put_env(:retro_hex_chat, :game_result_min_duration_ms, 0)
      on_exit(fn -> Application.delete_env(:retro_hex_chat, :game_result_min_duration_ms) end)
    end

    defp play_to_the_end(view, payload) do
      render_hook(view, "retro_game_canvas_ready", %{"game_id" => "hex_pong"})
      view |> element(~s([data-testid="retro-game-start-ai"])) |> render_click()
      render_hook(view, "retro_game_result", Map.put(payload, "game_id", "hex_pong"))
    end

    test "a signed-in player's match is written down and points at the game's channel", %{
      conn: conn
    } do
      nick = "Rank#{uid()}"
      {:ok, _} = register(nick)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.game_results())

      {:ok, view, _html} =
        conn |> chat_conn(nick, pre_identified: true) |> live(~p"/play/hex_pong")

      render_hook(view, "retro_game_canvas_ready", %{"game_id" => "hex_pong"})
      view |> element(~s([data-testid="retro-game-start-ai"])) |> render_click()

      # While the match runs, the chat's user list and the game's page can say so.
      assert %{game_id: "hex_pong"} = Activity.now()[Nickname.key(nick)]

      html =
        render_hook(view, "retro_game_result", %{
          "game_id" => "hex_pong",
          "score" => %{"p1" => 11, "p2" => 6},
          "winner" => 1
        })

      refute Map.has_key?(Activity.now(), Nickname.key(nick))

      assert html =~ "You won"
      assert html =~ "retro-game-recorded"
      assert html =~ "/c/hex-pong"

      assert_receive {:game_result_recorded, %{p1_nickname: ^nick, origin: "ai", outcome: "p1"}}
    end

    test "a match ended early is written down as it stood", %{conn: conn} do
      nick = "Early#{uid()}"
      {:ok, _} = register(nick)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.game_results())

      {:ok, view, _html} =
        conn |> chat_conn(nick, pre_identified: true) |> live(~p"/play/hex_pong")

      html =
        play_to_the_end(view, %{"score" => %{"p1" => 1, "p2" => 2}, "ended_early" => true})

      refute html =~ "AI won"
      assert html =~ "retro-game-ended-early"
      assert html =~ "retro-game-recorded"
      assert_receive {:game_result_recorded, %{p1_nickname: ^nick, outcome: "p2", ranked: false}}
    end

    test "a one-player game is written down as solo, with no difficulty", %{conn: conn} do
      nick = "Solo#{uid()}"
      {:ok, _} = register(nick)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.game_results())

      {:ok, view, _html} =
        conn |> chat_conn(nick, pre_identified: true) |> live(~p"/play/hex_jungle")

      render_hook(view, "retro_game_canvas_ready", %{"game_id" => "hex_jungle"})
      view |> element(~s([data-testid="retro-game-start-ai"])) |> render_click()

      render_hook(view, "retro_game_result", %{
        "game_id" => "hex_jungle",
        "score" => %{"p1" => 4200, "p2" => 0},
        "winner" => 0
      })

      assert_receive {:game_result_recorded,
                      %{p1_nickname: ^nick, origin: "solo", difficulty: nil, p1_score: 4200}}
    end

    # End pressed twice, or as the match ends on its own: the canvas reports
    # the result, then says it had nothing left to end. The result stays.
    test "a canvas with nothing left to end does not wipe a result already in", %{conn: conn} do
      nick = "Twice#{uid()}"
      {:ok, _} = register(nick)

      {:ok, view, _html} =
        conn |> chat_conn(nick, pre_identified: true) |> live(~p"/play/hex_pong")

      play_to_the_end(view, %{"score" => %{"p1" => 2, "p2" => 1}, "ended_early" => true})
      html = render_hook(view, "retro_game_stopped", %{"game_id" => "hex_pong"})

      assert html =~ "retro-game-result"
      assert html =~ "retro-game-ended-early"
    end

    test "a nickname typed without signing in plays unranked", %{conn: conn} do
      nick = "Typed#{uid()}"
      {:ok, _} = register(nick)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.game_results())

      {:ok, view, _html} = conn |> chat_conn(nick) |> live(~p"/play/hex_pong")
      html = play_to_the_end(view, %{"score" => %{"p1" => 3, "p2" => 11}, "winner" => 2})

      assert html =~ "AI won"
      assert html =~ "retro-game-unranked"
      refute_receive {:game_result_recorded, _row}
    end

    test "a result nobody started is ignored", %{conn: conn} do
      nick = "Stray#{uid()}"
      {:ok, _} = register(nick)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.game_results())

      {:ok, view, _html} =
        conn |> chat_conn(nick, pre_identified: true) |> live(~p"/play/hex_pong")

      html =
        render_hook(view, "retro_game_result", %{
          "game_id" => "hex_pong",
          "score" => %{"p1" => 11, "p2" => 0},
          "winner" => 1
        })

      refute html =~ "retro-game-result"
      refute_receive {:game_result_recorded, _row}
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
  end

  defp register(nickname) do
    RetroHexChat.Repo.insert(%RetroHexChat.Services.RegisteredNick{
      nickname: nickname,
      password_hash: "x",
      registered_at: DateTime.utc_now(),
      last_seen_at: DateTime.utc_now()
    })
  end

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
