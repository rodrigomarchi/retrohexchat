defmodule RetroHexChatWeb.LayoutAssetsTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Registry
  alias RetroHexChat.Channels.Supervisor
  alias RetroHexChatWeb.Icons.Sprite

  setup do
    case Registry.lookup("#lobby") do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child("#lobby")
    end

    :ok
  end

  # Every icon on the page is a <use> into one sprite. The browser only starts
  # fetching it when it hits the first <use>, which is after the document has
  # parsed — so each layout announces it up front and it downloads alongside
  # the stylesheet instead of after it.
  describe "the icon sprite is preloaded" do
    test "on the chat layout", %{conn: conn} do
      html = conn |> chat_conn("Sprite#{uid()}") |> get("/chat") |> html_response(200)

      assert html =~ preload_link()
    end

    test "on the landing layout", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      assert html =~ preload_link()
    end

    test "on the help layout", %{conn: conn} do
      html = conn |> get("/chat/help") |> html_response(200)

      assert html =~ preload_link()
    end
  end

  describe "the web font does not block the first paint" do
    test "every third-party stylesheet loads out of the render path", %{conn: conn} do
      chat = conn |> chat_conn("Font#{uid()}") |> get("/chat") |> html_response(200)
      landing = conn |> get("/") |> html_response(200)
      help = conn |> get("/chat/help") |> html_response(200)

      for {surface, html} <- [chat: chat, landing: landing, help: help] do
        links = third_party_stylesheets(html)

        assert links != [], "#{surface} lost its web font entirely"

        for link <- links do
          assert link =~ ~s(media="print"),
                 "#{surface} blocks the first paint on a third-party stylesheet: #{link}"
        end
      end
    end

    test "a no-JS reader still gets the font", %{conn: conn} do
      html = conn |> get("/") |> html_response(200)

      assert html =~ ~r{<noscript>.*fonts\.googleapis\.com.*</noscript>}s
    end
  end

  # `<noscript>` is where a blocking stylesheet still belongs: it only applies
  # when the promotion in `onload` can never run.
  defp third_party_stylesheets(html) do
    html
    |> String.replace(~r{<noscript>.*?</noscript>}s, "")
    |> then(&Regex.scan(~r{<link[^>]*https://fonts\.googleapis\.com[^>]*>}, &1))
    |> List.flatten()
    |> Enum.filter(&(&1 =~ ~s(rel="stylesheet")))
  end

  defp preload_link do
    ~s(<link rel="preload" as="image" type="image/svg+xml" href="#{Sprite.url()}">)
  end
end
