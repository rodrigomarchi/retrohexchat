defmodule RetroHexChatWeb.AccessoryPagesTest do
  @moduledoc """
  The public pages of Hex Paint and ASCII Art: each program shown in the
  pictures the capture took, described to a search engine as the web
  application it is, and a way in — straight to the program for a member,
  through an account for a visitor.

  The generic landing checks — one h1, the taskbar, a unique title and
  description — run over both from `Site.PagesTest`; what is asserted here is
  what is particular to them.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @moduletag :liveview

  alias RetroHexChatWeb.App.Paths

  @pages [
    %{path: "/paint", key: "paint", window: "paint", feature: :paint, name: "Hex Paint"},
    %{
      path: "/ascii-art",
      key: "ascii_art",
      window: "ascii-art",
      feature: :ascii_art,
      name: "ASCII Art"
    }
  ]

  defp document(conn, path),
    do: conn |> get(path) |> html_response(200) |> Floki.parse_document!()

  for page <- @pages do
    @page page

    test "#{@page.path} shows the program in the capture's pictures, each with its size and words",
         %{conn: conn} do
      images =
        conn
        |> document(@page.path)
        |> Floki.find("img")
        |> Enum.filter(&(Floki.attribute(&1, "src") |> List.first("") =~ "/images/tools/"))

      sources =
        images
        |> Enum.flat_map(&Floki.attribute(&1, "src"))
        |> Enum.map(&(&1 |> Path.basename() |> String.replace(~r/-[0-9a-f]{32}/, "")))
        |> Enum.uniq()
        |> Enum.sort()

      assert sources == Enum.sort(["#{@page.key}.webp", "in_chat.webp"])

      for image <- images do
        assert [_width] = Floki.attribute(image, "width")
        assert [alt] = Floki.attribute(image, "alt")
        assert alt != ""
      end
    end

    test "#{@page.path} is described as a web application and shared with its own card",
         %{conn: conn} do
      document = document(conn, @page.path)

      json_ld =
        document
        |> Floki.find(~s(script[type="application/ld+json"]))
        |> Enum.map(&(&1 |> Floki.children() |> Enum.join() |> Jason.decode!()))

      assert %{"name" => name, "url" => url} =
               Enum.find(json_ld, &(&1["@type"] == "WebApplication"))

      assert name == @page.name
      assert url =~ @page.path

      assert document
             |> Floki.find(~s(meta[property="og:image"]))
             |> Floki.attribute("content")
             |> List.first() =~ "/images/tools/og/#{@page.key}"
    end

    test "#{@page.path} asks a visitor for an account, then opens the program", %{conn: conn} do
      {:ok, view, _html} = live(conn, @page.path)

      assert view
             |> element(~s([data-testid="#{String.replace(@page.key, "_", "-")}-open"]))
             |> render() =~
               Paths.visitor_sign_in_path(@page.feature, Paths.chat_window_path(@page.window))
               |> Phoenix.HTML.html_escape()
               |> Phoenix.HTML.safe_to_string()
    end

    test "#{@page.path} opens the program on the desktop for a member", %{conn: conn} do
      {:ok, view, _html} = conn |> chat_conn("acc#{uid()}") |> live(@page.path)

      view
      |> element(~s([data-testid="#{String.replace(@page.key, "_", "-")}-open"]))
      |> render_click()

      assert_patch(view, Paths.chat_window_path(@page.window))
      assert @page.window in assigns(view).open_windows
    end
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns
end
