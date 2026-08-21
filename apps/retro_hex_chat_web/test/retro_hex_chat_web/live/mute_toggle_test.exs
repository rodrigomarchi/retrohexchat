defmodule RetroHexChatWeb.MuteToggleTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Chat.{PreferencePersistence, SoundSettings}
  alias RetroHexChat.Services.Queries

  describe "mute toggle in the system tray" do
    test "mute toggle button renders in the taskbar tray", %{conn: conn} do
      nick = "Mute#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      html = render(view)
      assert html =~ "data-testid=\"tray-mute-toggle\""
      assert html =~ "mute-toggle"
    end

    test "clicking mute toggles to muted state", %{conn: conn} do
      nick = "Mute#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element(~s([data-testid="tray-mute-toggle"]))
      |> render_click()

      html = render(view)
      assert html =~ "mute-toggle"

      # Toggle back
      view
      |> element(~s([data-testid="tray-mute-toggle"]))
      |> render_click()

      html = render(view)
      assert html =~ "mute-toggle"
    end

    test "toggle_mute pushes backend mute state to client", %{conn: conn} do
      nick = "Mute#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element(~s([data-testid="tray-mute-toggle"]))
      |> render_click()

      assert_push_event(view, "mute_state_changed", %{muted: true})
    end

    test "registered identified user loads persisted mute state from backend", %{conn: conn} do
      nick = "MuteP#{uid()}"
      insert_registered_nick(nick)

      assert :ok = SoundSettings.save(nick, muted_settings(true))

      {:ok, view, html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      assert assigns(view).muted == true
      assert html =~ ~s(data-muted="true")
      assert has_element?(view, ~s([data-testid="tray-mute-toggle"][title="Unmute"]))
      refute_push_event(view, "play_sound", %{})
    end

    test "toggle_mute persists for registered identified users", %{conn: conn} do
      nick = "MuteS#{uid()}"
      insert_registered_nick(nick)

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      view
      |> element(~s([data-testid="tray-mute-toggle"]))
      |> render_click()

      assert_push_event(view, "mute_state_changed", %{muted: true})
      assert assigns(view).muted == true
      assert {:ok, :applied} = PreferencePersistence.apply_pending(nick, "sound_settings")
      assert {:ok, loaded} = SoundSettings.load(nick)
      assert SoundSettings.muted?(loaded)

      view
      |> element(~s([data-testid="tray-mute-toggle"]))
      |> render_click()

      assert_push_event(view, "mute_state_changed", %{muted: false})
      assert assigns(view).muted == false
      assert {:ok, :applied} = PreferencePersistence.apply_pending(nick, "sound_settings")
      assert {:ok, loaded} = SoundSettings.load(nick)
      refute SoundSettings.muted?(loaded)
    end

    test "guest mute state stays in the LiveView process only", %{conn: conn} do
      nick = "MuteG#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element(~s([data-testid="tray-mute-toggle"]))
      |> render_click()

      assert_push_event(view, "mute_state_changed", %{muted: true})
      assert assigns(view).muted == true
      assert {:error, :not_found} = SoundSettings.load(nick)
    end

    test "sound settings apply preserves current mute state", %{conn: conn} do
      nick = "MuteD#{uid()}"
      insert_registered_nick(nick)

      {:ok, view, _html} = live(chat_conn(conn, nick, pre_identified: true), "/chat")

      render_click(view, "open_sound_settings_dialog", %{})

      view
      |> element(~s([data-testid="tray-mute-toggle"]))
      |> render_click()

      assert_push_event(view, "mute_state_changed", %{muted: true})

      view
      |> element(~s([data-testid="sound-settings-apply"]))
      |> render_click()

      assert assigns(view).muted == true
      assert {:ok, :applied} = PreferencePersistence.apply_pending(nick, "sound_settings")
      assert {:ok, loaded} = SoundSettings.load(nick)
      assert SoundSettings.muted?(loaded)
    end

    test "legacy mute_state_sync event is ignored", %{conn: conn} do
      nick = "Mute#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_hook(view, "mute_state_sync", %{"muted" => true})

      assert assigns(view).muted == false
    end
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  defp insert_registered_nick(nickname) do
    {:ok, _} = Queries.insert_registered_nick(nickname, "password123")
  end

  defp muted_settings(muted) do
    SoundSettings.new()
    |> SoundSettings.set_muted(muted)
  end
end
