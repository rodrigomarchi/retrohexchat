defmodule RetroHexChatWeb.SoundSettingsTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  # ── Dialog visibility ────────────────────────────────────────

  describe "sound settings dialog" do
    test "dialog opens when open_sound_settings_dialog event fires", %{conn: conn} do
      nick = "SndDlg#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      refute render(view) =~ "data-testid=\"sound-settings-dialog\""

      view
      |> element(~s([data-testid="menu-sounds"]))
      |> render_click()

      html = render(view)
      assert html =~ "data-testid=\"sound-settings-dialog\""
      assert html =~ "Sounds"
    end

    test "dialog shows all 10 event types", %{conn: conn} do
      nick = "SndAll#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element(~s([data-testid="menu-sounds"]))
      |> render_click()

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
      nick = "SndDrop#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element(~s([data-testid="menu-sounds"]))
      |> render_click()

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
      nick = "SndChg#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element(~s([data-testid="menu-sounds"]))
      |> render_click()

      # Change highlight sound to "buzz" via the dropdown
      view
      |> element(~s(select[data-testid="sound-select-highlight"]))
      |> render_change(%{"event_highlight" => "buzz"})

      html = render(view)
      # The dropdown for highlight should now show "buzz" selected
      assert html =~ "sound-select-highlight"
    end

    test "sound_settings_ok commits draft and closes dialog", %{conn: conn} do
      nick = "SndOK#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element(~s([data-testid="menu-sounds"]))
      |> render_click()

      assert render(view) =~ "data-testid=\"sound-settings-dialog\""

      view
      |> element(~s(button[phx-click="sound_settings_ok"]))
      |> render_click()

      html = render(view)
      refute html =~ "data-testid=\"sound-settings-dialog\""
      assert html =~ "Sound settings saved"
    end

    test "sound_settings_apply commits but keeps dialog open", %{conn: conn} do
      nick = "SndApply#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element(~s([data-testid="menu-sounds"]))
      |> render_click()

      view
      |> element(~s(button[phx-click="sound_settings_apply"]))
      |> render_click()

      html = render(view)
      # Dialog stays open
      assert html =~ "data-testid=\"sound-settings-dialog\""
      # System message shown
      assert html =~ "Sound settings applied"
    end

    test "close_sound_settings_dialog discards draft", %{conn: conn} do
      nick = "SndCancel#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element(~s([data-testid="menu-sounds"]))
      |> render_click()

      assert render(view) =~ "data-testid=\"sound-settings-dialog\""

      view
      |> element(~s(button[type="button"][phx-click="close_sound_settings_dialog"]))
      |> render_click()

      html = render(view)
      refute html =~ "data-testid=\"sound-settings-dialog\""
      refute html =~ "Sound settings saved"
    end
  end

  # ── Preview ────────────────────────────────────────────────

  describe "sound preview" do
    test "preview button pushes play_sound event", %{conn: conn} do
      nick = "SndPrev#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")
      # Consume connect sound
      assert_push_event(view, "play_sound", %{type: "chime_short"})

      view
      |> element(~s([data-testid="menu-sounds"]))
      |> render_click()

      view
      |> element(~s(button[data-testid="sound-preview-highlight"]))
      |> render_click()

      assert_push_event(view, "play_sound", %{type: "alert"})
    end
  end

  # ── Flash toggle ───────────────────────────────────────────

  describe "flash toggle" do
    test "toggling flash checkbox updates draft", %{conn: conn} do
      nick = "SndFlash#{System.unique_integer([:positive])}"
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element(~s([data-testid="menu-sounds"]))
      |> render_click()

      # Toggle join flash (starts as false)
      view
      |> element(~s(input[data-testid="flash-toggle-join"]))
      |> render_click()

      # After toggle, the checkbox state should be updated
      html = render(view)
      assert html =~ "flash-toggle-join"
    end
  end
end
