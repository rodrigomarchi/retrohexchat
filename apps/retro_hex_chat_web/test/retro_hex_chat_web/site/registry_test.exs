defmodule RetroHexChatWeb.Site.RegistryTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChatWeb.ChatLive.WindowRegistry
  alias RetroHexChatWeb.Live.PutLocale
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO
  alias RetroHexChatWeb.Site.Registry

  defp desktop_routes do
    Enum.filter(
      Phoenix.Router.routes(RetroHexChatWeb.Router),
      &(&1.plug == Phoenix.LiveView.Plug and
          match?(%{phoenix_live_view: {RetroHexChatWeb.DesktopLive, _, _, _}}, &1.metadata))
    )
  end

  test "every address of the desktop opens a page or the chat itself" do
    routes = desktop_routes()
    assert routes != []

    for %{path: path, metadata: %{phoenix_live_view: {_, action, _, _}}} <- routes do
      assert Registry.page(action) != nil or action == :channel,
             "#{path} (#{action}) opens neither a page nor the chat"
    end
  end

  test "every page in the menus and the sitemap has an address on the desktop" do
    paths = MapSet.new(desktop_routes(), & &1.path)

    for page <- PublicPages.all() ++ PublicPages.guides() do
      assert page.path in paths, "#{page.path} is listed but the desktop has no route for it"
    end
  end

  test "a document window's id is never a window the chat already has" do
    chat_ids = MapSet.new(WindowRegistry.windows(), & &1.id)

    for id <- Registry.window_ids() do
      refute id in chat_ids, "#{id} is both a document window and a chat window"
    end

    assert Registry.window_ids() == Enum.uniq(Registry.window_ids())
  end

  # A locale segment is the first segment of an address; one spelled like a
  # path the desktop already uses would make that path mean two things.
  test "no locale segment is spelled like one of the desktop's own paths" do
    reserved = ~w(c chat connect join archive games play call space p2p api locale showcase)

    for segment <- SEO.localized_locale_segments() do
      refute String.downcase(segment) in reserved, "#{segment} is a reserved path segment"
    end
  end

  describe "the locale an address names" do
    test "is its first segment" do
      assert PutLocale.locale_of(URI.parse("http://x/pt-BR/c/lobby")) == "pt_BR"
      assert PutLocale.locale_of(URI.parse("http://x/ja")) == "ja"
    end

    # A connected mount's URI is the socket's own (/live/websocket), so the
    # page's address arrives in the connect params.
    test "on the socket, is the page path's first segment" do
      assert PutLocale.locale_of_page(%{"page_path" => "/pt-BR/faq"}) == "pt_BR"
      assert PutLocale.locale_of_page(%{"page_path" => "/faq"}) == "en"
      assert PutLocale.locale_of(URI.parse("ws://x/live/websocket")) == "en"
      assert PutLocale.locale_of_page(%{"page_path" => "//evil"}) == "en"
      assert PutLocale.locale_of_page(nil) == "en"
    end

    test "is the default without one, or with one that is not a locale" do
      assert PutLocale.locale_of(URI.parse("http://x/c/lobby")) == "en"
      assert PutLocale.locale_of(URI.parse("http://x/xx/faq")) == "en"
      assert PutLocale.locale_of(nil) == "en"
    end
  end
end
