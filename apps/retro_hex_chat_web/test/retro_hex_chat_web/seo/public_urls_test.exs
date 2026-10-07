defmodule RetroHexChatWeb.SEO.PublicUrlsTest do
  @moduledoc """
  What IndexNow announces is what the sitemap offers, cut by the day it changed.
  """
  use RetroHexChatWeb.ConnCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.Archive
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Repo
  alias RetroHexChat.SEO.IndexNow
  alias RetroHexChat.Services.RegisteredChannel
  alias RetroHexChatWeb.SEO
  alias RetroHexChatWeb.SEO.PublicUrls

  describe "pages_changed_since/1" do
    test "every page with a known day, in every language, is one the sitemap offers", %{
      conn: conn
    } do
      announced = PublicUrls.pages_changed_since(~D[1970-01-01])
      offered = sitemap_locs(conn)

      assert announced != []
      assert announced -- offered == []
      assert "https://retrohexchat.app/pt-BR/chat/help/cmd-ban" in announced
    end

    test "a page whose day is before the cutoff is left out" do
      assert PublicUrls.pages_changed_since(Date.add(Date.utc_today(), 1)) == []
    end

    test "the cutoff day itself is included" do
      {path, lastmod} =
        Enum.find(PublicUrls.localized_paths(), fn {_path, lastmod} -> lastmod end)

      urls = PublicUrls.pages_changed_since(Date.from_iso8601!(String.slice(lastmod, 0, 10)))

      assert SEO.site_url(path) in urls
    end
  end

  describe "archive_day/1" do
    setup do
      channel = "#idx#{System.unique_integer([:positive])}"

      {:ok, _} =
        Repo.insert(%RegisteredChannel{
          name: channel,
          founder_nickname: "Founder",
          registered_at: DateTime.utc_now(),
          last_activity_at: DateTime.utc_now()
        })

      {:ok, _} = Archive.publish(channel)

      {:ok, message} =
        Queries.insert_message(%{
          channel_name: channel,
          author_nickname: "Speaker",
          content: "worth finding",
          plain_content: "worth finding",
          type: "message"
        })

      %{slug: String.trim_leading(channel, "#"), day: DateTime.to_date(message.inserted_at)}
    end

    test "names the channel's index and the day's page", ctx do
      urls = PublicUrls.archive_day(ctx.day)

      assert "https://retrohexchat.app/archive/#{ctx.slug}" in urls
      assert "https://retrohexchat.app/archive/#{ctx.slug}/#{ctx.day}" in urls
    end

    test "a day the channel was quiet adds nothing for it", ctx do
      urls = PublicUrls.archive_day(Date.add(ctx.day, -3))

      refute Enum.any?(urls, &String.contains?(&1, "/archive/#{ctx.slug}"))
    end
  end

  describe "GET /indexnow.txt" do
    test "answers the key as plain text", %{conn: conn} do
      conn = get(conn, "/indexnow.txt")

      assert response(conn, 200) == IndexNow.key()
      assert response_content_type(conn, :text) =~ "text/plain"
    end
  end

  defp sitemap_locs(conn) do
    index = conn |> get("/sitemap.xml") |> response(200)

    ~r{<loc>https://retrohexchat\.app(/sitemaps/[^<]+)</loc>}
    |> Regex.scan(index, capture: :all_but_first)
    |> Enum.flat_map(fn [path] ->
      body = build_conn() |> get(path) |> response(200)
      Regex.scan(~r{<loc>([^<]+)</loc>}, body, capture: :all_but_first) |> List.flatten()
    end)
  end
end
