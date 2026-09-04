defmodule RetroHexChatWeb.ShowcaseSEOTest do
  use RetroHexChatWeb.ConnCase, async: true

  alias RetroHexChatWeb.SEO
  alias RetroHexChatWeb.ShowcaseCatalog

  @moduletag :showcase

  defp document(conn, path),
    do: conn |> get(path) |> html_response(200) |> Floki.parse_document!()

  defp attribute(doc, selector, name),
    do: doc |> Floki.find(selector) |> Floki.attribute(name) |> List.first()

  describe "indexability" do
    test "every showcase page invites indexing and names its own canonical URL", %{conn: conn} do
      for path <- ShowcaseCatalog.paths() do
        doc = document(conn, path)

        assert attribute(doc, "meta[name=robots]", "content") == "index, follow",
               "#{path} is not indexable"

        assert attribute(doc, "link[rel=canonical]", "href") == SEO.site_url(path),
               "#{path} points its canonical elsewhere"
      end
    end

    test "pages carry a description of their own", %{conn: conn} do
      button = attribute(document(conn, "/showcase/button"), "meta[name=description]", "content")
      index = attribute(document(conn, "/showcase"), "meta[name=description]", "content")

      assert button =~ "Button"
      refute button == index
    end

    # English-only by design: a component demo's value is the component, not the
    # prose around it, so translating 106 pages would add thin duplicates.
    test "no locale alternates are advertised", %{conn: conn} do
      doc = document(conn, "/showcase/button")

      assert Floki.find(doc, "link[rel=alternate]") == []
    end

    test "structured data describes the page", %{conn: conn} do
      json =
        conn
        |> get("/showcase/button")
        |> html_response(200)
        |> then(&Regex.run(~r|<script type="application/ld\+json">(.*?)</script>|s, &1))
        |> Enum.at(1)
        |> Jason.decode!()

      assert json["@type"] == "SoftwareSourceCode"
      assert json["url"] == SEO.site_url("/showcase/button")
    end
  end

  describe "sitemap" do
    test "lists every showcase path exactly once", %{conn: conn} do
      locations =
        conn
        |> get("/sitemap.xml")
        |> response(200)
        |> then(&Regex.scan(~r|/sitemaps/([\w.-]+)|, &1))
        |> Enum.map(&List.last/1)
        |> Enum.filter(&String.starts_with?(&1, "showcase"))
        |> Enum.flat_map(fn name ->
          Phoenix.ConnTest.build_conn()
          |> get("/sitemaps/#{name}")
          |> response(200)
          |> then(&Regex.scan(~r|<loc>([^<]+)</loc>|, &1))
          |> Enum.map(&List.last/1)
        end)

      expected = Enum.map(ShowcaseCatalog.paths(), &SEO.site_url/1)

      assert Enum.sort(locations) == Enum.sort(expected)
      assert locations == Enum.uniq(locations)
    end
  end

  # The window manager only decorates markup the server already sent. These are
  # the properties that keep that true — break one and the desktop stops being
  # something a crawler can read.
  describe "what a crawler receives" do
    test "the page content is inline, not fetched when a window opens", %{conn: conn} do
      doc = document(conn, "/showcase/button")

      assert Floki.find(doc, "[data-window-managed=true]") == []

      assert doc |> Floki.find(~s([data-testid="showcase-component-window"])) |> Floki.text() =~
               "Button"
    end

    test "every component is reachable through a real link", %{conn: conn} do
      hrefs =
        conn
        |> document("/showcase")
        |> Floki.find("a[href]")
        |> Floki.attribute("href")
        |> MapSet.new()

      for entry <- ShowcaseCatalog.entries() do
        assert ShowcaseCatalog.path(entry) in hrefs,
               "#{entry.id} has no crawlable link on the index"
      end
    end

    # The catalog hangs off the Components window, not the Start menu, which is
    # the same menu on every screen. What matters is that a crawler finds every
    # component from any component page — not which piece of chrome the links
    # happen to sit in.
    test "every component page links to every other component", %{conn: conn} do
      hrefs =
        conn
        |> document("/showcase/button")
        |> Floki.find("a[href]")
        |> Floki.attribute("href")
        |> MapSet.new()

      for entry <- ShowcaseCatalog.entries() do
        assert ShowcaseCatalog.path(entry) in hrefs,
               "#{entry.id} is unreachable from /showcase/button"
      end
    end

    test "the Start menu navigates with real links, not buttons alone", %{conn: conn} do
      links =
        conn
        |> document("/showcase/button")
        |> Floki.find("[data-window-start-menu] a[href]")
        |> Floki.attribute("href")

      # The public pages plus the docs — the Start menu's own navigation, which
      # has to work with scripting off like the rest of the desktop.
      assert "/" in links
      assert "/faq" in links
      assert "/chat/help" in links
    end
  end
end
