defmodule RetroHexChatWeb.ChatLive.OptionsEvents do
  @moduledoc """
  Handle Options dialog events.

  Covers: open/close, panel selection, display toggles,
  OK/Apply/Cancel with draft state pattern.

  Attached as `attach_hook(:options_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.UserPreferences
  alias RetroHexChatWeb.ChatLive.Helpers.Persistence

  # ---------------------------------------------------------------------------
  # Dialog Lifecycle
  # ---------------------------------------------------------------------------

  def handle_event("open_options_dialog", _params, socket) do
    if socket.assigns.show_options_dialog do
      {:halt, socket}
    else
      draft = socket.assigns.session.user_preferences
      {:halt, assign(socket, show_options_dialog: true, options_draft: draft)}
    end
  end

  def handle_event("close_options_dialog", _params, socket) do
    {:halt, assign(socket, show_options_dialog: false, options_draft: nil)}
  end

  def handle_event("options_select_panel", %{"panel" => panel}, socket) do
    {:halt, assign(socket, options_panel: panel)}
  end

  def handle_event("options_ok", _params, socket) do
    socket =
      socket
      |> apply_draft()
      |> assign(show_options_dialog: false, options_draft: nil)

    {:halt, socket}
  end

  def handle_event("options_apply", _params, socket) do
    {:halt, apply_draft(socket)}
  end

  # ---------------------------------------------------------------------------
  # Display Panel
  # ---------------------------------------------------------------------------

  def handle_event("options_toggle_display", %{"setting" => setting_str}, socket) do
    setting = String.to_existing_atom(setting_str)
    draft = socket.assigns.options_draft
    current = Map.get(draft.display, setting)
    updated_draft = UserPreferences.set_display(draft, setting, !current)
    {:halt, assign(socket, options_draft: updated_draft)}
  end

  # ---------------------------------------------------------------------------
  # Catch-all
  # ---------------------------------------------------------------------------

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ---------------------------------------------------------------------------
  # Private: Apply draft to live state
  # ---------------------------------------------------------------------------

  defp apply_draft(socket) do
    draft = socket.assigns.options_draft
    session = socket.assigns.session

    updated_session = Session.set_user_preferences(session, draft)

    socket
    |> assign(
      session: updated_session,
      options_draft: draft,
      show_toolbar: draft.display.show_toolbar,
      show_conversations: draft.display.show_conversations,
      show_switchbar: draft.display.show_switchbar,
      show_statusbar: draft.display.show_statusbar
    )
    |> push_event("feedback_toast", %{message: "Settings saved", duration: 2000})
    |> Persistence.maybe_persist_user_preferences(updated_session)
  end
end
