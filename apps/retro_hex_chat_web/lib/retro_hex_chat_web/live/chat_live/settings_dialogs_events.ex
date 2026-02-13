defmodule RetroHexChatWeb.ChatLive.SettingsDialogsEvents do
  @moduledoc """
  Handle events for the CTCP Settings, Flood Protection, and Sound Settings dialogs,
  plus the global mute toggle.

  Covers: open_ctcp_settings_dialog, close_ctcp_settings_dialog, ctcp_save_settings,
  open_flood_protection_dialog, close_flood_protection_dialog, flood_save_settings,
  flood_reset_defaults, open_sound_settings_dialog, close_sound_settings_dialog,
  sound_settings_change, sound_flash_toggle, sound_preview, sound_settings_apply,
  sound_settings_ok, toggle_mute.

  Attached as an `attach_hook(:settings_dialogs_events, :handle_event, ...)` in ChatLive.mount/3.
  Returns `{:halt, socket}` when the event is handled, `{:cont, socket}` otherwise.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [stream_insert: 3, push_event: 3]
  import RetroHexChatWeb.ChatLive.Helpers, only: [system_message: 1]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{CtcpSettings, FloodProtection, SoundSettings}

  # ── CTCP Settings ───────────────────────────────────────────

  def handle_event("open_ctcp_settings_dialog", _params, socket) do
    {:halt, assign(socket, show_ctcp_settings_dialog: true)}
  end

  def handle_event("close_ctcp_settings_dialog", _params, socket) do
    {:halt, assign(socket, show_ctcp_settings_dialog: false)}
  end

  def handle_event("ctcp_save_settings", params, socket) do
    session = socket.assigns.session
    settings = session.ctcp_settings

    settings =
      settings
      |> CtcpSettings.set_enabled(params["enabled"] == "true")
      |> CtcpSettings.set_version_string(params["version_string"] || "RetroHexChat v1.0")
      |> CtcpSettings.set_finger_text(
        case params["finger_text"] do
          "" -> nil
          nil -> nil
          text -> text
        end
      )

    new_session = Session.set_ctcp_settings(session, settings)

    if new_session.identified do
      Task.start(fn ->
        CtcpSettings.save(new_session.nickname, settings)
      end)
    end

    {:halt,
     socket
     |> assign(session: new_session, show_ctcp_settings_dialog: false)
     |> stream_insert(
       :chat_messages,
       system_message("* CTCP settings saved")
     )}
  end

  # ── Flood Protection ────────────────────────────────────────

  def handle_event("open_flood_protection_dialog", _params, socket) do
    {:halt, assign(socket, show_flood_protection_dialog: true)}
  end

  def handle_event("close_flood_protection_dialog", _params, socket) do
    {:halt, assign(socket, show_flood_protection_dialog: false)}
  end

  def handle_event("flood_save_settings", params, socket) do
    session = socket.assigns.session
    settings = session.flood_protection

    settings =
      settings
      |> try_set(&FloodProtection.set_flood_threshold/2, params["flood_threshold"])
      |> try_set(&FloodProtection.set_flood_window_seconds/2, params["flood_window_seconds"])
      |> try_set(
        &FloodProtection.set_auto_ignore_duration_seconds/2,
        params["auto_ignore_duration_seconds"]
      )
      |> try_set(&FloodProtection.set_spam_threshold/2, params["spam_threshold"])
      |> try_set(&FloodProtection.set_spam_window_seconds/2, params["spam_window_seconds"])
      |> try_set(&FloodProtection.set_ctcp_reply_limit/2, params["ctcp_reply_limit"])
      |> try_set(
        &FloodProtection.set_ctcp_reply_window_seconds/2,
        params["ctcp_reply_window_seconds"]
      )

    new_session = Session.set_flood_protection(session, settings)

    if new_session.identified do
      Task.start(fn -> FloodProtection.save(new_session.nickname, settings) end)
    end

    {:halt,
     socket
     |> assign(session: new_session, show_flood_protection_dialog: false)
     |> stream_insert(
       :chat_messages,
       system_message("* Flood protection settings saved")
     )}
  end

  def handle_event("flood_reset_defaults", _params, socket) do
    session = socket.assigns.session
    defaults = FloodProtection.new()
    new_session = Session.set_flood_protection(session, defaults)

    if new_session.identified do
      Task.start(fn -> FloodProtection.save(new_session.nickname, defaults) end)
    end

    {:halt,
     socket
     |> assign(session: new_session, show_flood_protection_dialog: false)
     |> stream_insert(
       :chat_messages,
       system_message("* Flood protection settings reset to defaults")
     )}
  end

  # ── Sound Settings ──────────────────────────────────────────

  def handle_event("open_sound_settings_dialog", _params, socket) do
    draft = socket.assigns.session.sound_settings

    {:halt,
     assign(socket,
       show_sound_settings_dialog: true,
       sound_settings_draft: draft
     )}
  end

  def handle_event("close_sound_settings_dialog", _params, socket) do
    {:halt,
     assign(socket,
       show_sound_settings_dialog: false,
       sound_settings_draft: nil
     )}
  end

  def handle_event("sound_settings_change", params, socket) do
    draft = socket.assigns.sound_settings_draft

    updated_draft =
      Enum.reduce(SoundSettings.event_types(), draft, fn event, acc ->
        key = "event_#{event}"

        case Map.get(params, key) do
          nil -> acc
          sound_name -> SoundSettings.set_sound(acc, event, sound_name)
        end
      end)

    {:halt, assign(socket, sound_settings_draft: updated_draft)}
  end

  def handle_event("sound_flash_toggle", %{"event" => event_str}, socket) do
    event = String.to_existing_atom(event_str)
    draft = socket.assigns.sound_settings_draft
    current = SoundSettings.get_flash(draft, event)
    updated_draft = SoundSettings.set_flash(draft, event, not current)

    {:halt, assign(socket, sound_settings_draft: updated_draft)}
  end

  def handle_event("sound_preview", %{"event" => event_str}, socket) do
    event = String.to_existing_atom(event_str)
    draft = socket.assigns.sound_settings_draft
    sound = SoundSettings.get_sound(draft, event)

    if sound == "none" do
      {:halt, socket}
    else
      {:halt, push_event(socket, "play_sound", %{type: sound})}
    end
  end

  def handle_event("sound_settings_apply", _params, socket) do
    draft = socket.assigns.sound_settings_draft
    session = socket.assigns.session
    new_session = Session.set_sound_settings(session, draft)

    if new_session.identified do
      Task.start(fn -> SoundSettings.save(new_session.nickname, draft) end)
    end

    {:halt,
     socket
     |> assign(session: new_session)
     |> stream_insert(
       :chat_messages,
       system_message("* Sound settings applied")
     )}
  end

  def handle_event("sound_settings_ok", _params, socket) do
    draft = socket.assigns.sound_settings_draft
    session = socket.assigns.session
    new_session = Session.set_sound_settings(session, draft)

    if new_session.identified do
      Task.start(fn -> SoundSettings.save(new_session.nickname, draft) end)
    end

    {:halt,
     socket
     |> assign(
       session: new_session,
       show_sound_settings_dialog: false,
       sound_settings_draft: nil
     )
     |> stream_insert(
       :chat_messages,
       system_message("* Sound settings saved")
     )}
  end

  # ── Mute Toggle ─────────────────────────────────────────────

  def handle_event("toggle_mute", _params, socket) do
    new_muted = not socket.assigns.muted

    {:halt,
     socket
     |> assign(muted: new_muted)
     |> push_event("toggle_mute", %{})}
  end

  # ── Catch-all: pass unhandled events to next hook ───────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private helpers ─────────────────────────────────────────

  @spec try_set(map(), (map(), integer() -> map() | {:error, atom()}), String.t() | nil) ::
          map()
  defp try_set(settings, _setter, nil), do: settings

  defp try_set(settings, setter, value_str) do
    case Integer.parse(value_str) do
      {value, _} ->
        case setter.(settings, value) do
          {:error, _} -> settings
          updated -> updated
        end

      :error ->
        settings
    end
  end
end
