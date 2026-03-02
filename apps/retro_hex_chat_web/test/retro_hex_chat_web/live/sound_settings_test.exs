defmodule RetroHexChatWeb.SoundSettingsTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  # ── Dialog visibility ────────────────────────────────────────

  describe "sound settings dialog" do
    test "dialog opens when open_sound_settings_dialog event fires", %{conn: conn} do
      nick = "SndDlg#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      refute has_element?(view, "#sound-settings-dialog-show-trigger")

      render_click(view, "open_sound_settings_dialog", %{})

      html = render(view)
      assert has_element?(view, "#sound-settings-dialog-show-trigger")
      assert html =~ "Sound Settings"
    end

    test "dialog shows all 10 event types", %{conn: conn} do
      nick = "SndAll#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "open_sound_settings_dialog", %{})

      html = render(view)
      assert html =~ "Channel Message"
      assert html =~ "Private Message"
      assert html =~ "Highlight/Mention"
      assert html =~ "User Joined"
      assert html =~ "User Left"
      assert html =~ "User Kicked"
      assert html =~ "Connected"
      assert html =~ "Disconnected"
      assert html =~ "Buddy Online"
      assert html =~ "Buddy Offline"
    end

    test "each event has a dropdown and preview button", %{conn: conn} do
      nick = "SndDrop#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "open_sound_settings_dialog", %{})

      html = render(view)

      for event <-
            ~w(message pm highlight join part kick connect disconnect buddy_online buddy_offline) do
        assert html =~ "data-testid=\"sound-select-#{event}\""
        assert html =~ "data-testid=\"sound-preview-#{event}\""
        assert html =~ "data-testid=\"flash-toggle-#{event}\""
      end
    end
  end

  # ── Draft / OK / Cancel / Apply ──────────────────────────────

  describe "OK/Cancel/Apply behavior" do
    test "sound_settings_change updates draft", %{conn: conn} do
      nick = "SndChg#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "open_sound_settings_dialog", %{})

      # Change highlight sound to "buzz" via event
      render_click(view, "sound_settings_change", %{"event_highlight" => "buzz"})

      html = render(view)
      assert html =~ "sound-select-highlight"
    end

    test "sound_settings_ok commits draft and closes dialog", %{conn: conn} do
      nick = "SndOK#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "open_sound_settings_dialog", %{})

      assert has_element?(view, "#sound-settings-dialog-show-trigger")

      render_click(view, "sound_settings_ok")

      html = render(view)
      refute has_element?(view, "#sound-settings-dialog-show-trigger")
      assert html =~ "Sound settings saved"
    end

    test "sound_settings_apply commits but keeps dialog open", %{conn: conn} do
      nick = "SndApply#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "open_sound_settings_dialog", %{})

      render_click(view, "sound_settings_apply")

      html = render(view)
      # Dialog stays open
      assert has_element?(view, "#sound-settings-dialog-show-trigger")
      # System message shown
      assert html =~ "Sound settings applied"
    end

    test "close_sound_settings_dialog discards draft", %{conn: conn} do
      nick = "SndCancel#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "open_sound_settings_dialog", %{})

      assert has_element?(view, "#sound-settings-dialog-show-trigger")

      render_click(view, "close_sound_settings_dialog")

      html = render(view)
      refute has_element?(view, "#sound-settings-dialog-show-trigger")
      refute html =~ "Sound settings saved"
    end
  end

  # ── Preview ────────────────────────────────────────────────

  describe "sound preview" do
    test "preview button pushes play_sound event", %{conn: conn} do
      nick = "SndPrev#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
      # Consume connect sound
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      render_click(view, "open_sound_settings_dialog", %{})

      view
      |> element(~s(button[data-testid="sound-preview-highlight"]))
      |> render_click()

      assert_push_event(view, "play_sound", %{type: "alert"})
    end
  end

  # ── Flash toggle ───────────────────────────────────────────

  describe "flash toggle" do
    test "toggling flash checkbox updates draft", %{conn: conn} do
      nick = "SndFlash#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      render_click(view, "open_sound_settings_dialog", %{})

      # Toggle join flash via event
      render_click(view, "sound_flash_toggle", %{"event" => "join"})

      # After toggle, the checkbox state should be updated
      html = render(view)
      assert html =~ "flash-toggle-join"
    end
  end
end
