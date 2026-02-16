defmodule RetroHexChatWeb.FavoritesAutojoinTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}
  alias RetroHexChat.Chat.Favorites
  alias RetroHexChat.Services.NickServ

  setup do
    ensure_channel("#lobby")
    :ok
  end

  describe "auto-join favorites on connect" do
    test "auto-joins favorites marked with auto-join after identification", %{conn: conn} do
      # Register and set up favorites with auto-join
      nick = "AutoFav#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      ensure_channel("#autofav1")
      ensure_channel("#autofav2")

      # Create favorites with auto-join
      favorites = Favorites.new()

      {:ok, favorites} =
        Favorites.add_entry(favorites, %{channel_name: "#autofav1", auto_join: true})

      {:ok, favorites} =
        Favorites.add_entry(favorites, %{channel_name: "#autofav2", auto_join: false})

      :ok = Favorites.save(nick, favorites)

      # Connect and identify
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      # Wait for perform + autojoin chain to complete
      Process.sleep(500)

      html = render(view)
      # #autofav1 (auto_join: true) should be joined
      assert html =~ "#autofav1"
      # #autofav2 (auto_join: false) should NOT be joined
      refute html =~ "channel-#autofav2"
    end

    test "does not auto-join favorites without auto-join flag", %{conn: conn} do
      nick = "NoAutoFav#{System.unique_integer([:positive])}"
      NickServ.register(nick, "pass123")

      ensure_channel("#nonauto")

      favorites = Favorites.new()

      {:ok, favorites} =
        Favorites.add_entry(favorites, %{channel_name: "#nonauto", auto_join: false})

      :ok = Favorites.save(nick, favorites)

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/ns identify pass123"})

      Process.sleep(500)

      html = render(view)
      refute html =~ "channel-#nonauto"
    end
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
