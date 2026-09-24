defmodule RetroHexChatWeb.ArchiveControllerTest do
  @moduledoc """
  The only page of this product a stranger can read.

  Everything asserted here is about who is allowed to see what. A channel that
  never agreed answers 404 rather than 403, because 403 would confirm that the
  channel exists — and the existence of a room is itself something a secret
  channel is entitled to keep. The rest is the shape a robot needs: a real
  status, an unprefixed canonical under every locale, and an `etag` it can ask
  about instead of downloading the day again.
  """
  use RetroHexChatWeb.ConnCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.Archive
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredChannel

  setup do
    channel = "#arch#{uid()}"
    register(channel)
    %{channel: channel, slug: String.trim_leading(channel, "#")}
  end

  describe "a channel that does not publish" do
    test "the index answers 404", ctx do
      conn = get(build_conn(), ~p"/archive/#{ctx.slug}")

      assert conn.status == 404
    end

    test "a day answers 404", ctx do
      conn = get(build_conn(), ~p"/archive/#{ctx.slug}/2026-09-24")

      assert conn.status == 404
    end

    # 404 and not 403: the second confirms the channel exists, and for a room
    # that never agreed to be public that confirmation is the leak.
    test "a channel nobody registered answers 404 the same way" do
      conn = get(build_conn(), ~p"/archive/nosuchchannel")

      assert conn.status == 404
    end

    test "a secret channel answers 404 even with the switch on", ctx do
      {:ok, _} = Archive.publish(ctx.channel)
      message(ctx.channel, "said in the open, then made secret")
      set_modes(ctx.channel, "+s")

      assert get(build_conn(), ~p"/archive/#{ctx.slug}").status == 404
    end
  end

  describe "a published channel" do
    setup ctx do
      {:ok, _} = Archive.publish(ctx.channel)
      said = message(ctx.channel, "the meeting notes live at example.test/notes")
      %{said: said, date: day_of(said)}
    end

    # `get/2` rather than `live/2` on purpose: the dead render is what a robot
    # receives, and it is the only thing that can be indexed.
    test "the index lists the days", ctx do
      body = build_conn() |> get(~p"/archive/#{ctx.slug}") |> html_response(200)

      assert body =~ ctx.date
      assert body =~ ctx.channel
    end

    test "the day shows what was said", ctx do
      body = build_conn() |> get(~p"/archive/#{ctx.slug}/#{ctx.date}") |> html_response(200)

      assert body =~ "the meeting notes live at example.test/notes"
      assert body =~ "Speaker"
    end

    test "a day with nothing in it answers 404", ctx do
      assert get(build_conn(), ~p"/archive/#{ctx.slug}/1999-01-01").status == 404
    end

    test "a date that is not a date answers 404", ctx do
      assert get(build_conn(), ~p"/archive/#{ctx.slug}/not-a-date").status == 404
    end

    test "the page is indexable", ctx do
      body = build_conn() |> get(~p"/archive/#{ctx.slug}") |> html_response(200)

      assert body =~ ~s(name="robots" content="index, follow")
      refute body =~ "noindex"
    end

    # A conversation has no translated version, so the canonical is the same
    # URL under every locale and there are no hreflang alternates at all.
    test "the canonical is unprefixed, and there are no alternates", ctx do
      body = build_conn() |> get(~p"/pt-BR/archive/#{ctx.slug}") |> html_response(200)

      assert body =~ ~s(rel="canonical")
      assert body =~ "/archive/#{ctx.slug}\""
      refute body =~ "/pt-BR/archive/#{ctx.slug}\""
      refute body =~ ~s(rel="alternate")
    end

    test "the prefixed path answers rather than raising", ctx do
      assert build_conn() |> get(~p"/pt-BR/archive/#{ctx.slug}/#{ctx.date}") |> html_response(200)
    end

    test "the second request can be answered with 304", ctx do
      first = get(build_conn(), ~p"/archive/#{ctx.slug}/#{ctx.date}")
      assert [etag] = get_resp_header(first, "etag")

      second =
        build_conn()
        |> put_req_header("if-none-match", etag)
        |> get(~p"/archive/#{ctx.slug}/#{ctx.date}")

      assert second.status == 304
      assert second.resp_body == ""
    end

    test "a changed day gets a different etag", ctx do
      [before] =
        build_conn() |> get(~p"/archive/#{ctx.slug}/#{ctx.date}") |> get_resp_header("etag")

      message(ctx.channel, "and one more thing")
      [now] = build_conn() |> get(~p"/archive/#{ctx.slug}/#{ctx.date}") |> get_resp_header("etag")

      refute before == now
    end

    # Turning the switch off has to take the page with it. A cached body would
    # keep answering, which is the one failure this feature cannot have.
    # A cache that holds one of these pages keeps serving a page its channel has
    # withdrawn. Revalidation is free for a robot — the etag answers 304 — and
    # it is the only setting under which switching off actually switches off.
    test "nothing is allowed to serve a withdrawn page from a cache", ctx do
      conn = get(build_conn(), ~p"/archive/#{ctx.slug}/#{ctx.date}")

      assert ["public, max-age=0, must-revalidate"] = get_resp_header(conn, "cache-control")
    end

    test "unpublishing takes the page down", ctx do
      assert get(build_conn(), ~p"/archive/#{ctx.slug}/#{ctx.date}").status == 200

      {:ok, _} = Archive.unpublish(ctx.channel)

      assert get(build_conn(), ~p"/archive/#{ctx.slug}/#{ctx.date}").status == 404
      assert get(build_conn(), ~p"/archive/#{ctx.slug}").status == 404
    end

    test "a deleted line stops being served", ctx do
      {:ok, _} = Queries.soft_delete(ctx.said, DateTime.utc_now())

      assert get(build_conn(), ~p"/archive/#{ctx.slug}/#{ctx.date}").status == 404
    end
  end

  describe "the sitemap" do
    test "offers a published channel's days", ctx do
      {:ok, _} = Archive.publish(ctx.channel)
      said = message(ctx.channel, "worth finding")

      body = build_conn() |> get(~p"/sitemaps/archive.xml") |> response(200)

      assert body =~ "/archive/#{ctx.slug}</loc>"
      assert body =~ "/archive/#{ctx.slug}/#{day_of(said)}</loc>"
      # A conversation has no translated version.
      refute body =~ "hreflang"
    end

    # The chunk is built per request for exactly this: every other chunk is
    # cached for the life of the node, and a cached one would keep offering
    # pages that stopped answering.
    test "stops offering them the moment the channel unpublishes", ctx do
      {:ok, _} = Archive.publish(ctx.channel)
      message(ctx.channel, "worth finding")
      assert build_conn() |> get(~p"/sitemaps/archive.xml") |> response(200) =~ ctx.slug

      {:ok, _} = Archive.unpublish(ctx.channel)

      refute build_conn() |> get(~p"/sitemaps/archive.xml") |> response(200) =~ ctx.slug
    end

    test "the index names the archive chunk" do
      body = build_conn() |> get(~p"/sitemap.xml") |> response(200)

      assert body =~ "/sitemaps/archive.xml"
    end
  end

  defp register(name) do
    {:ok, _} =
      Repo.insert(%RegisteredChannel{
        name: name,
        founder_nickname: "Founder",
        registered_at: DateTime.utc_now(),
        last_activity_at: DateTime.utc_now()
      })
  end

  defp set_modes(name, modes) do
    RegisteredChannel
    |> Repo.get_by!(name: name)
    |> Ecto.Changeset.change(modes: modes)
    |> Repo.update!()
  end

  defp message(channel, content) do
    {:ok, message} =
      Queries.insert_message(%{
        channel_name: channel,
        author_nickname: "Speaker",
        content: content,
        plain_content: content,
        type: "message"
      })

    message
  end

  defp day_of(message), do: message.inserted_at |> DateTime.to_date() |> Date.to_iso8601()
end
