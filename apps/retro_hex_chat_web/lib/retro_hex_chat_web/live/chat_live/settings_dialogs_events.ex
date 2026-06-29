defmodule RetroHexChatWeb.ChatLive.SettingsDialogsEvents do
  @moduledoc """
  Handle events for the Flood Protection and Sound Settings dialogs,
  plus the global mute toggle.

  Covers: open_flood_protection_dialog, close_flood_protection_dialog, flood_save_settings,
  flood_reset_defaults, open_sound_settings_dialog, close_sound_settings_dialog,
  sound_settings_change, sound_flash_toggle, sound_preview, sound_settings_apply,
  sound_settings_ok, toggle_mute.

  Attached as an `attach_hook(:settings_dialogs_events, :handle_event, ...)` in ChatLive.mount/3.
  Returns `{:halt, socket}` when the event is handled, `{:cont, socket}` otherwise.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers, only: [system_message: 1]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{FloodProtection, SoundSettings}
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport
  alias RetroHexChatWeb.ChatLive.Components.SoundSettingsDialog

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

    new_session = Session.set_flood_protection(session, settings)

    if new_session.identified do
      Task.start(fn -> FloodProtection.save(new_session.nickname, settings) end)
    end

    {:halt,
     socket
     |> assign(session: new_session, show_flood_protection_dialog: false)
     |> MessageViewport.insert(
       system_message(dgettext("chat", "* Flood protection settings saved"))
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
     |> MessageViewport.insert(
       system_message(dgettext("chat", "* Flood protection settings reset to defaults"))
     )}
  end

  # ── Sound Settings ──────────────────────────────────────────

  def handle_event("open_sound_settings_dialog", _params, socket) do
    send_update(SoundSettingsDialog,
      id: SoundSettingsDialog.id(),
      action: {:open, socket.assigns.session.sound_settings}
    )

    {:halt, assign(socket, show_sound_settings_dialog: true)}
  end

  def handle_event("close_sound_settings_dialog", _params, socket) do
    send_update(SoundSettingsDialog, id: SoundSettingsDialog.id(), action: :close)
    {:halt, assign(socket, show_sound_settings_dialog: false)}
  end

  # Sound-dropdown change must be a string event (the design-system `select_item`
  # does `JS.push(on_sound_change, value:)`), so it bubbles here and we forward the
  # raw params to the component, which applies them to its own draft.
  def handle_event("sound_settings_change", params, socket) do
    send_update(SoundSettingsDialog, id: SoundSettingsDialog.id(), action: {:change, params})
    {:halt, socket}
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

  # ── handle_info: commit the sound draft from the LiveComponent ───
  #
  # `SoundSettingsDialog` owns the draft (a struct) and hands it up here on
  # Apply/OK via `send(self(), ...)`; this handler commits it to the session and
  # persists it. `:apply` keeps the dialog open; `:ok` also closes it (and resets
  # the component's draft).
  @spec handle_info(term(), Phoenix.LiveView.Socket.t()) ::
          {:halt | :cont, Phoenix.LiveView.Socket.t()}
  def handle_info({:commit_sound_settings, draft, mode}, socket) do
    session = socket.assigns.session
    new_session = Session.set_sound_settings(session, draft)

    if new_session.identified do
      Task.start(fn -> SoundSettings.save(new_session.nickname, draft) end)
    end

    socket =
      socket
      |> assign(session: new_session)
      |> MessageViewport.insert(system_message(commit_message(mode)))

    {:halt, maybe_close_sound_dialog(socket, mode)}
  end

  def handle_info(_msg, socket), do: {:cont, socket}

  # ── Private helpers ─────────────────────────────────────────

  @spec commit_message(:apply | :ok) :: String.t()
  defp commit_message(:apply), do: dgettext("chat", "* Sound settings applied")
  defp commit_message(:ok), do: dgettext("chat", "* Sound settings saved")

  @spec maybe_close_sound_dialog(Phoenix.LiveView.Socket.t(), :apply | :ok) ::
          Phoenix.LiveView.Socket.t()
  defp maybe_close_sound_dialog(socket, :apply), do: socket

  defp maybe_close_sound_dialog(socket, :ok) do
    send_update(SoundSettingsDialog, id: SoundSettingsDialog.id(), action: :close)
    assign(socket, show_sound_settings_dialog: false)
  end

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
