defmodule RetroHexChatWeb.JoinLiveTest do
  @moduledoc """
  The public card a shared link resolves to.

  This is the first thing a stranger sees of the product, so its four states are
  asserted individually: a link is alive far less of the time than it exists,
  and the dead card has to be useful too.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.ShareLinks

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
