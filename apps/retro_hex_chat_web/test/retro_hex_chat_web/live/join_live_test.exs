defmodule RetroHexChatWeb.JoinLiveTest do
  @moduledoc """
  The public card a shared link resolves to.

  This is the first thing a stranger sees of the product, so its four states are
  asserted individually: a link is alive far less of the time than it exists,
  and the dead card has to be useful too.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Registry
  alias RetroHexChat.ShareLinks
  alias RetroHexChat.VirtualSpace
  alias RetroHexChatWeb.App.Paths

  setup do
    nick = "Sharer#{uid()}"
    {:ok, registered} = register(nick)
    %{nick: nick, user_id: registered.id}
  end

  describe "a live link" do
    test "invites a visitor with no session to connect and come back", %{conn: conn} = ctx do
      slug = share(ctx, "play", %{"game_id" => "hex_pong"})

      {:ok, view, html} = live(conn, ~p"/join/#{slug}")

      assert html =~ "join-card"

      assert [href] =
               view
               |> element(~s([data-testid="join-enter"]))
               |> render()
               |> Floki.parse_fragment!()
               |> Floki.attribute("href")

      assert href =~ "/connect"
      assert URI.decode(href) =~ "return_to=/join/#{slug}"
    end

    test "offers a signed-in visitor the way in", %{conn: conn} = ctx do
      slug = share(ctx, "play", %{"game_id" => "hex_pong"})

      {:ok, view, _html} = conn |> chat_conn(ctx.nick) |> live(~p"/join/#{slug}")

      # A link, not an event: the surface lives in another live_session, so
      # entering is a navigation the browser makes and not a round trip.
      assert view
             |> element(~s([data-testid="join-enter"]))
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.attribute("href") == ["/play/hex_pong"]
    end
  end

  # A space is the one kind that is never dead: it is a place rather than an
  # event, so its address stays good even when nobody is standing in it.
  describe "a link to a space" do
    setup do
      channel = "#join#{uid()}"
      {:ok, channel_pid} = Supervisor.start_child(channel)

      on_exit(fn ->
        if Process.alive?(channel_pid) do
          Supervisor.stop_child(Supervisor, channel_pid)
        end
      end)

      %{channel: channel}
    end

    test "points a signed-in visitor at the space itself", ctx do
      %{conn: conn, channel: channel} = ctx
      slug = share(ctx, "space", %{"space_id" => channel, "mode" => "channel"})

      {:ok, view, _html} = conn |> chat_conn(ctx.nick) |> live(~p"/join/#{slug}")

      assert view
             |> element(~s([data-testid="join-enter"]))
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.attribute("href") == [Paths.space_path(channel)]
    end

    test "names a channel a stranger could have found anyway", ctx do
      %{conn: conn, channel: channel} = ctx
      {:ok, _state} = Server.join(channel, ctx.nick)
      slug = share(ctx, "space", %{"space_id" => channel, "mode" => "channel"})

      {:ok, _view, html} = live(conn, ~p"/join/#{slug}")

      assert html =~ channel
    end

    # The id of a private space is its two participants, so the card says
    # nothing at all about which one it is.
    test "a private space names nobody", ctx do
      %{conn: conn} = ctx
      space_id = VirtualSpace.direct_message_space_id("zoltar", "brunhilde")
      slug = share(ctx, "space", %{"space_id" => space_id, "mode" => "direct_message"})

      {:ok, _view, html} = live(conn, ~p"/join/#{slug}")

      assert html =~ "A private space"
      refute html =~ "zoltar"
      refute html =~ "brunhilde"
    end
  end

  # The preview tags are the surface the privacy rule was written for: a card
  # body is read by somebody who already followed the link, and a preview is read
  # by everybody the link was forwarded to. Asserted on `get/2` rather than
  # `live/2` because the `<head>` only exists in the dead render — which is also
  # the only thing a crawler or a chat unfurler ever fetches.
  describe "the link preview" do
    setup do
      channel = "#prev#{uid()}"
      {:ok, channel_pid} = Supervisor.start_child(channel)

      on_exit(fn ->
        if Process.alive?(channel_pid) do
          Supervisor.stop_child(Supervisor, channel_pid)
        end
      end)

      %{channel: channel}
    end

    test "says what was shared instead of the site's generic blurb", ctx do
      %{conn: conn, channel: channel} = ctx
      {:ok, _state} = Server.join(channel, ctx.nick)
      slug = share(ctx, "space", %{"space_id" => channel, "mode" => "channel"})

      head = conn |> get(~p"/join/#{slug}") |> html_response(200) |> head_of()

      assert head =~ channel
      refute head =~ "Run your own chat server"
    end

    test "never names a channel the reader could not have listed", ctx do
      %{conn: conn, channel: channel} = ctx
      {:ok, _state} = Server.join(channel, ctx.nick)
      :ok = Server.set_mode(channel, ctx.nick, "+s")

      slug = share(ctx, "space", %{"space_id" => channel, "mode" => "channel"})

      head = conn |> get(~p"/join/#{slug}") |> html_response(200) |> head_of()

      refute head =~ channel
      assert head =~ "A space on RetroHexChat"
    end

    test "a dead link says nothing about what it used to point at", %{conn: conn} do
      head = conn |> get(~p"/join/abcdefghjk") |> html_response(200) |> head_of()

      assert head =~ "Join - RetroHexChat"
    end
  end

  describe "a link that no longer works" do
    test "an unknown slug says so without saying whether it ever existed", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/join/abcdefghjk")

      assert html =~ "join-card"
      assert html =~ "join-gone"
      refute html =~ "join-enter"
    end

    test "a revoked slug reads the same as an unknown one", %{conn: conn} = ctx do
      slug = share(ctx, "play", %{"game_id" => "hex_pong"})
      {:ok, _} = ShareLinks.revoke(slug, ctx.nick)

      {:ok, _view, html} = live(conn, ~p"/join/#{slug}")

      assert html =~ "join-gone"
      refute html =~ "join-enter"
    end

    test "a link whose game left the catalogue is gone, not broken", %{conn: conn} = ctx do
      slug = share(ctx, "play", %{"game_id" => "no_such_game"})

      {:ok, _view, html} = conn |> chat_conn(ctx.nick) |> live(~p"/join/#{slug}")

      assert html =~ "join-gone"
      refute html =~ "join-enter"
    end

    # Every dead card offers the next plausible thing rather than a dead end.
    test "a dead card still points somewhere", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/join/abcdefghjk")

      assert html =~ "join-elsewhere"
    end
  end

  # Found by hand, in Firefox, on a pt-BR browser: the route existed only
  # unprefixed, so a visitor whose locale had rewritten the URL got a router
  # error instead of the card. Every public page here lives under every locale
  # segment, and the address is the one thing about a shared link that nobody
  # who received it can fix.
  describe "under a locale segment" do
    test "resolves the same card", %{conn: conn} = ctx do
      slug = share(ctx, "play", %{"game_id" => "hex_pong"})

      for segment <- RetroHexChatWeb.SEO.localized_locale_segments() do
        {:ok, _view, html} = live(conn, "/#{segment}/join/#{slug}")

        assert html =~ "join-card", "expected /#{segment}/join/:slug to render the card"
      end
    end

    test "a dead link is dead in every locale too", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/pt-BR/join/abcdefghjk")

      assert html =~ "join-gone"
    end
  end

  # The card is public, so it carries nothing a crawler should keep.
  test "is not indexable", %{conn: conn} = ctx do
    slug = share(ctx, "play", %{"game_id" => "hex_pong"})

    html = conn |> get(~p"/join/#{slug}") |> html_response(200)

    assert html =~ "noindex"
  end

  # A match link is the one kind that dies by succeeding, so it gets its own
  # block: "already full" is the answer most late clicks on a 1v1 link get, and
  # it must not read like an expired link.
  describe "a match link" do
    setup ctx do
      session = open_match(ctx.user_id)

      slug =
        share(ctx, "play", %{"game_id" => "hex_pong", "session_token" => session.token})

      %{session: session, slug: slug}
    end

    test "an empty seat is offered, and the way in is the match", %{conn: conn} = ctx do
      {:ok, view, html} = conn |> chat_conn(ctx.nick) |> live(~p"/join/#{ctx.slug}")

      assert html =~ "1 seat open"

      assert view
             |> element(~s([data-testid="join-enter"]))
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.attribute("href") == ["/play/hex_pong/#{ctx.session.token}"]
    end

    test "a taken seat says the match is full, not that the link expired", %{conn: conn} = ctx do
      {:ok, claimer} = register("Claimer#{uid()}")
      {:ok, _claimed} = Lobby.claim_open_session(ctx.session.token, claimer.id)
      stop_lobby(ctx.session.token)

      {:ok, view, html} = conn |> chat_conn("Stranger#{uid()}") |> live(~p"/join/#{ctx.slug}")

      assert html =~ ~s(data-testid="join-filled")
      assert html =~ "Somebody already took the seat"
      refute html =~ "Link expired"

      # Never who took it: a link anybody may hold must not become a way of
      # learning who answered it.
      refute html =~ claimer.nickname

      # And never a dead end.
      assert has_element?(view, ~s([data-testid="join-play-instead"]))
      assert has_element?(view, ~s([data-testid="join-elsewhere"]))
    end

    test "whoever is already in it still gets the way in", %{conn: conn} = ctx do
      {:ok, claimer} = register("Claimer#{uid()}")
      {:ok, _claimed} = Lobby.claim_open_session(ctx.session.token, claimer.id)
      stop_lobby(ctx.session.token)

      {:ok, view, html} = conn |> chat_conn(ctx.nick) |> live(~p"/join/#{ctx.slug}")

      refute html =~ ~s(data-testid="join-filled")

      assert view
             |> element(~s([data-testid="join-enter"]))
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.attribute("href") == ["/play/hex_pong/#{ctx.session.token}"]
    end

    test "a match that is over reads as a dead link, like every other kind",
         %{conn: conn} = ctx do
      :ok = Lobby.close_session(ctx.session.token, ctx.user_id, "user_closed")

      {:ok, _view, html} = conn |> chat_conn(ctx.nick) |> live(~p"/join/#{ctx.slug}")

      assert html =~ ~s(data-testid="join-gone")
    end
  end

  defp open_match(user_id) do
    {:ok, %{session: session}} =
      Lobby.create_open_session(user_id, metadata: %{"game_id" => "hex_pong"})

    on_exit(fn -> stop_lobby(session.token) end)
    session
  end

  defp stop_lobby(token) do
    case Registry.lookup(token) do
      {:ok, pid} -> GenServer.stop(pid, :normal)
      {:error, :not_found} -> :ok
    end
  catch
    :exit, _reason -> :ok
  end

  # Only the head: the card body legitimately names things the tags must not.
  defp head_of(html) do
    case String.split(html, "</head>", parts: 2) do
      [head, _body] -> head
      [whole] -> whole
    end
  end

  defp share(ctx, kind, target) do
    {:ok, link} =
      ShareLinks.create(%{
        kind: kind,
        target: target,
        creator_id: ctx.user_id,
        creator_nick: ctx.nick
      })

    link.slug
  end

  defp register(nickname) do
    RetroHexChat.Repo.insert(%RetroHexChat.Services.RegisteredNick{
      nickname: nickname,
      password_hash: "x",
      registered_at: DateTime.utc_now(),
      last_seen_at: DateTime.utc_now()
    })
  end
end
