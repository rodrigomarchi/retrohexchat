defmodule RetroHexChatWeb.ChatLive.NotifyEvents do
  @moduledoc """
  Handle events for the Notify List panel.

  Covers: toggle_notify_list, notify_add, notify_remove, notify_edit, notify_select,
  notify_add_dialog, notify_add_cancel, notify_edit_dialog, notify_edit_cancel,
  notify_dblclick, toggle_auto_whois.

  Attached as `attach_hook(:notify_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      maybe_persist_notify_list: 2,
      push_status_message: 3,
      cancel_notify_timer: 2,
      open_pm_conversation: 2
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Presence.{NotifyList, Tracker}

  def handle_event("toggle_notify_list", _params, socket) do
    {:halt, assign(socket, show_notify_list: !socket.assigns.show_notify_list)}
  end

  def handle_event("notify_add", %{"nickname" => nick} = params, socket) do
    session = socket.assigns.session
    note = params["note"]
    note = if note == "", do: nil, else: note

    case NotifyList.add_entry(session.notify_list, session.nickname, nick, note) do
      {:ok, updated_list} ->
        updated_list = sync_entry_online(updated_list, nick)
        new_session = Session.set_notify_list(session, updated_list)

        {:halt,
         socket
         |> assign(session: new_session, show_notify_add_dialog: false)
         |> maybe_persist_notify_list(new_session)
         |> push_status_message(
           dgettext("chat", "Added %{nickname} to notify list", nickname: nick),
           :system
         )}

      {:error, :self_add} ->
        {:halt,
         push_status_message(
           socket,
           dgettext("chat", "Cannot add yourself to the notify list"),
           :system
         )}

      {:error, :duplicate} ->
        {:halt,
         push_status_message(
           socket,
           dgettext("chat", "%{nickname} is already in your notify list", nickname: nick),
           :system
         )}

      {:error, :list_full} ->
        {:halt,
         push_status_message(
           socket,
           dgettext("chat", "Notify list is full (max 50 entries)"),
           :system
         )}
    end
  end

  def handle_event("notify_remove", params, socket) do
    nick = params["nickname"] || socket.assigns.notify_selected

    if nick do
      session = socket.assigns.session

      case NotifyList.remove_entry(session.notify_list, nick) do
        {:ok, updated_list} ->
          new_session = Session.set_notify_list(session, updated_list)

          # Cancel any pending debounce timer for this buddy
          socket = cancel_notify_timer(socket, nick)

          {:halt,
           socket
           |> assign(session: new_session, notify_selected: nil, selected_notify_note: "")
           |> maybe_persist_notify_list(new_session)
           |> push_status_message(
             dgettext("chat", "Removed %{nickname} from notify list", nickname: nick),
             :system
           )}

        {:error, :not_found} ->
          {:halt,
           push_status_message(
             socket,
             dgettext("chat", "%{nickname} is not in your notify list", nickname: nick),
             :system
           )}
      end
    else
      {:halt, socket}
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
         |> assign(
           session: new_session,
           show_notify_edit_dialog: false,
           selected_notify_note: note || ""
         )
         |> maybe_persist_notify_list(new_session)
         |> push_status_message(
           dgettext("chat", "Updated note for %{nickname}", nickname: nick),
           :system
         )}

      {:error, :not_found} ->
        {:halt,
         push_status_message(
           socket,
           dgettext("chat", "%{nickname} is not in your notify list", nickname: nick),
           :system
         )}
    end
  end

  def handle_event("notify_select", %{"nickname" => nick}, socket) do
    note = notify_note(socket.assigns.session.notify_list, nick)

    {:halt, assign(socket, notify_selected: nick, selected_notify_note: note)}
  end

  def handle_event("notify_add_dialog", _params, socket) do
    {:halt, assign(socket, show_notify_add_dialog: true)}
  end

  def handle_event("notify_add_cancel", _params, socket) do
    {:halt, assign(socket, show_notify_add_dialog: false)}
  end

  def handle_event("notify_edit_dialog", _params, socket) do
    note = notify_note(socket.assigns.session.notify_list, socket.assigns.notify_selected)

    {:halt, assign(socket, show_notify_edit_dialog: true, selected_notify_note: note)}
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

  def handle_event("toggle_auto_add_pm", _params, socket) do
    session = socket.assigns.session
    current = NotifyList.auto_add_pm?(session.notify_list)
    updated_list = NotifyList.set_auto_add_pm(session.notify_list, !current)
    new_session = Session.set_notify_list(session, updated_list)

    socket =
      socket
      |> assign(session: new_session)
      |> maybe_persist_notify_list(new_session)

    {:halt, socket}
  end

  # ── Catch-all ──────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private helpers ──────────────────────────────────────

  @spec sync_entry_online(map(), String.t()) :: map()
  defp sync_entry_online(notify_list, nickname) do
    online_nicks =
      Tracker.list_users("presence:global")
      |> Enum.map(& &1.nickname)

    if Enum.any?(online_nicks, &(String.downcase(&1) == String.downcase(nickname))) do
      NotifyList.set_online(notify_list, nickname, true)
    else
      notify_list
    end
  end

  defp notify_note(notify_list, nick) when is_binary(nick) do
    downcased = String.downcase(nick)

    notify_list.entries
    |> Enum.find(&(String.downcase(&1.tracked_nickname) == downcased))
    |> case do
      nil -> ""
      entry -> Map.get(entry, :note) || ""
    end
  end

  defp notify_note(_notify_list, _nick), do: ""
end
