defmodule RetroHexChatWeb.SpacesPageTest do
  @moduledoc """
  The public Spaces page: the world shown in real pictures, found by search
  engines and shared as itself, and a way into the busiest channel's Space.

  The generic landing checks — one h1, the taskbar, the lightweight bundle, a
  unique title and description — run over it from `Site.PagesTest`; what is
  asserted here is what is particular to this page.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @moduletag :liveview

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.App.Paths

  defp document(conn, path),
    do: conn |> get(path) |> html_response(200) |> Floki.parse_document!()

  defp lobby_space, do: Paths.space_path("#lobby")

  test "shows the world in pictures the capture took, each with its size", %{conn: conn} do
    images = conn |> document("/spaces") |> Floki.find("img")

    sources =
      images
      |> Floki.attribute("src")
      |> Enum.filter(&String.contains?(&1, "/images/spaces/"))
      |> Enum.map(&(&1 |> Path.basename() |> String.replace(~r/-[0-9a-f]{32}/, "")))
      |> Enum.uniq()
      |> Enum.sort()

    assert sources ==
             ~w(construct.webp creator.webp game_room.webp island.webp office.webp)

    for image <- images, src <- Floki.attribute(image, "src"), src =~ "/images/spaces/" do
      assert [_width] = Floki.attribute(image, "width")
      assert [_height] = Floki.attribute(image, "height")
      assert [alt] = Floki.attribute(image, "alt")
      assert alt != ""
    end
  end

  test "is shared with a picture of the island", %{conn: conn} do
    document = document(conn, "/spaces")

    assert document
           |> Floki.find(~s(meta[property="og:image"]))
           |> Floki.attribute("content")
           |> List.first() =~ "/images/spaces/og/spaces"

    assert document
           |> Floki.find(~s(meta[property="og:image:width"]))
           |> Floki.attribute("content") == ["1200"]
  end

  test "a visitor's way in asks for an account and comes back into the #lobby Space",
       %{conn: conn} do
    {:ok, view, _html} = live(conn, "/spaces")

    href =
      view
      |> element(~s([data-testid="spaces-enter"]))
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.attribute("href")
      |> List.first()

    assert href == Paths.visitor_sign_in_path(:space, lobby_space())
    assert href =~ "signup=space"
  end

  test "a member walks straight into the #lobby Space, in a tab of its own", %{conn: conn} do
    {:ok, view, _html} = conn |> chat_conn("spc#{uid()}") |> live("/spaces")

    [link] =
      view
      |> element(~s([data-testid="spaces-enter"]))
      |> render()
      |> Floki.parse_fragment!()

    assert Floki.attribute(link, "href") == [lobby_space()]
  end

  test "is in every language, under its own address", %{conn: conn} do
    document = document(conn, "/pt-BR/spaces")

    assert document
           |> Floki.find(~s(link[rel="canonical"]))
           |> Floki.attribute("href") == ["https://retrohexchat.app/pt-BR/spaces"]

    hreflangs = document |> Floki.find(~s(link[rel="alternate"])) |> Floki.attribute("href")
    assert "https://retrohexchat.app/spaces" in hreflangs
  end

  test "is listed in the sitemap" do
    sitemaps =
      ~r{<loc>https://retrohexchat\.app(/sitemaps/[^<]+)</loc>}
      |> Regex.scan(response(get(build_conn(), "/sitemap.xml"), 200), capture: :all_but_first)
      |> List.flatten()

    body = Enum.map_join(sitemaps, &response(get(build_conn(), &1), 200))

    assert body =~ "<loc>https://retrohexchat.app/spaces</loc>"
  end

  test "every help topic it links to exists", %{conn: conn} do
    topics =
      conn
      |> document("/spaces")
      |> Floki.find("a")
      |> Floki.attribute("href")
      |> Enum.flat_map(
        &(Regex.run(~r{/chat/help/([a-z0-9-]+)$}, &1, capture: :all_but_first) || [])
      )
      |> Enum.uniq()

    assert "feature-space-construct" in topics

    for topic <- topics do
      assert HelpTopics.get_topic(topic), "#{topic} is not a help topic"
    end
  end
end
