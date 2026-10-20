defmodule RetroHexChatWeb.SoundSettingsTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  # ── Dialog visibility ────────────────────────────────────────

  describe "sound settings dialog" do
    test "dialog opens when open_sound_settings_dialog event fires", %{conn: conn} do
      nick = "SndDlg#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/")

      refute has_element?(view, ~s([data-window-id="sound-settings"]))

      render_click(view, "open_sound_settings_dialog", %{})

      html = render(view)
      assert has_element?(view, ~s([data-window-id="sound-settings"][data-window-managed="true"]))
      assert html =~ "Sound Settings"
    end
  end

  # ── Draft / OK / Cancel / Apply ──────────────────────────────

  describe "OK/Cancel/Apply behavior" do
    test "sound_settings_ok commits draft and closes dialog", %{conn: conn} do
      nick = "SndOK#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/")

      render_click(view, "open_sound_settings_dialog", %{})

      assert has_element?(view, ~s([data-window-id="sound-settings"]))

      # OK is owned by the SoundSettingsDialog LiveComponent; click the element so
      # the event routes to the component (which commits the draft via the parent).
      view |> element(~s([data-testid="sound-settings-ok"])) |> render_click()

      html = render(view)
      # Managed window: OK closes it, unmounting the island.
      refute has_element?(view, ~s([data-window-id="sound-settings"]))
      assert html =~ "Sound settings saved"
    end

    test "sound_settings_apply commits but keeps dialog open", %{conn: conn} do
      nick = "SndApply#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/")

      render_click(view, "open_sound_settings_dialog", %{})

      view |> element(~s([data-testid="sound-settings-apply"])) |> render_click()

      html = render(view)
      # Apply keeps the window open
      assert has_element?(view, ~s([data-window-id="sound-settings"]))
      # System message shown
      assert html =~ "Sound settings applied"
    end

    test "close_sound_settings_dialog discards draft", %{conn: conn} do
      nick = "SndCancel#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/")

      render_click(view, "open_sound_settings_dialog", %{})

      assert has_element?(view, ~s([data-window-id="sound-settings"]))

      render_click(view, "close_sound_settings_dialog")

      html = render(view)
      refute has_element?(view, ~s([data-window-id="sound-settings"]))
      refute html =~ "Sound settings saved"
    end
  end

  # ── Preview ────────────────────────────────────────────────

  describe "sound preview" do
    test "preview button pushes play_sound event", %{conn: conn} do
      nick = "SndPrev#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nick), "/")
      # Consume connect sound
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      render_click(view, "open_sound_settings_dialog", %{})

      view
      |> element(~s(button[data-testid="sound-preview-highlight"]))
      |> render_click()

      assert_push_event(view, "play_sound", %{type: "alert"})
    end
  end
end
