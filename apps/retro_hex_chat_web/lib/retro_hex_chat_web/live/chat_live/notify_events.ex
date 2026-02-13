defmodule RetroHexChatWeb.ChatLive.NotifyEvents do
  @moduledoc """
  Handle events for the Notify List panel.

  Covers: toggle_notify_list, notify_add, notify_remove, notify_edit, notify_select,
  notify_add_dialog, notify_add_cancel, notify_edit_dialog, notify_edit_cancel,
  notify_dblclick, toggle_auto_whois.

  Attached as `attach_hook(:notify_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      maybe_persist_notify_list: 2,
      push_status_message: 3,
      cancel_notify_timer: 2,
      open_pm_conversation: 2
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Presence.NotifyList

  def handle_event("toggle_notify_list", _params, socket) do
    {:halt, assign(socket, show_notify_list: !socket.assigns.show_notify_list)}
  end

  def handle_event("notify_add", %{"nickname" => nick} = params, socket) do
    session = socket.assigns.session
    note = params["note"]
    note = if note == "", do: nil, else: note

    case NotifyList.add_entry(session.notify_list, session.nickname, nick, note) do
      {:ok, updated_list} ->
        new_session = Session.set_notify_list(session, updated_list)

        {:halt,
         socket
         |> assign(session: new_session, show_notify_add_dialog: false)
         |> maybe_persist_notify_list(new_session)
         |> push_status_message("Added #{nick} to notify list", :system)}

      {:error, :self_add} ->
        {:halt, push_status_message(socket, "Cannot add yourself to the notify list", :system)}

      {:error, :duplicate} ->
        {:halt, push_status_message(socket, "#{nick} is already in your notify list", :system)}

      {:error, :list_full} ->
        {:halt, push_status_message(socket, "Notify list is full (max 50 entries)", :system)}
    end
  end

  def handle_event("notify_remove", %{"nickname" => nick}, socket) do
    session = socket.assigns.session

    case NotifyList.remove_entry(session.notify_list, nick) do
      {:ok, updated_list} ->
        new_session = Session.set_notify_list(session, updated_list)

        # Cancel any pending debounce timer for this buddy
        socket = cancel_notify_timer(socket, nick)

        {:halt,
         socket
         |> assign(session: new_session, notify_selected: nil)
         |> maybe_persist_notify_list(new_session)
         |> push_status_message("Removed #{nick} from notify list", :system)}

      {:error, :not_found} ->
        {:halt, push_status_message(socket, "#{nick} is not in your notify list", :system)}
    end
  end

  def handle_event("notify_edit", %{"nickname" => nick, "note" => note}, socket) do
    session = socket.assigns.session
    note = if note == "", do: nil, else: note

    case NotifyList.update_note(session.notify_list, nick, note) do
      {:ok, updated_list} ->
        new_session = Session.set_notify_list(session, updated_list)

        {:halt,
         socket
         |> assign(session: new_session, show_notify_edit_dialog: false)
         |> maybe_persist_notify_list(new_session)
         |> push_status_message("Updated note for #{nick}", :system)}

      {:error, :not_found} ->
        {:halt, push_status_message(socket, "#{nick} is not in your notify list", :system)}
    end
  end

  def handle_event("notify_select", %{"nickname" => nick}, socket) do
    {:halt, assign(socket, notify_selected: nick)}
  end

  def handle_event("notify_add_dialog", _params, socket) do
    {:halt, assign(socket, show_notify_add_dialog: true)}
  end

  def handle_event("notify_add_cancel", _params, socket) do
    {:halt, assign(socket, show_notify_add_dialog: false)}
  end

  def handle_event("notify_edit_dialog", _params, socket) do
    {:halt, assign(socket, show_notify_edit_dialog: true)}
  end

  def handle_event("notify_edit_cancel", _params, socket) do
    {:halt, assign(socket, show_notify_edit_dialog: false)}
  end

  def handle_event("notify_dblclick", %{"nickname" => nick}, socket) do
    session = socket.assigns.session

    entry =
      Enum.find(session.notify_list.entries, fn e ->
        String.downcase(e.tracked_nickname) == String.downcase(nick)
      end)

    if entry && entry.online do
      {:halt, open_pm_conversation(socket, nick)}
    else
      {:halt, socket}
    end
  end

  def handle_event("toggle_auto_whois", _params, socket) do
    session = socket.assigns.session
    current = session.notify_list.settings.auto_whois
    updated_list = NotifyList.set_auto_whois(session.notify_list, !current)
    new_session = Session.set_notify_list(session, updated_list)

    socket =
      socket
      |> assign(session: new_session)
      |> maybe_persist_notify_list(new_session)

    {:halt, socket}
  end

  # ── Catch-all ──────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
