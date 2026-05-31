defmodule RetroHexChatWeb.ChatLive.UiActions.Notify do
  @moduledoc """
  Notify list UI actions: add, remove, edit, list display, open dialog.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      push_status_message: 3,
      maybe_persist_notify_list: 2
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Presence.{NotifyList, Tracker}

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :open_notify_list, _payload) do
    assign(socket, show_notify_list: true)
  end

  def handle_ui_action(socket, :notify_add, %{nickname: nick, note: note}) do
    session = socket.assigns.session

    case NotifyList.add_entry(session.notify_list, session.nickname, nick, note) do
      {:ok, updated_list} ->
        updated_list = sync_entry_online(updated_list, nick)
        new_session = Session.set_notify_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_notify_list(new_session)
        |> push_status_message(
          gettext("Added %{nickname} to notify list", nickname: nick),
          :system
        )

      {:error, :self_add} ->
        push_status_message(socket, gettext("Cannot add yourself to the notify list"), :system)

      {:error, :duplicate} ->
        push_status_message(
          socket,
          gettext("%{nickname} is already in your notify list", nickname: nick),
          :system
        )

      {:error, :list_full} ->
        push_status_message(socket, gettext("Notify list is full (max 50 entries)"), :system)
    end
  end

  def handle_ui_action(socket, :notify_remove, %{nickname: nick}) do
    session = socket.assigns.session

    case NotifyList.remove_entry(session.notify_list, nick) do
      {:ok, updated_list} ->
        new_session = Session.set_notify_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_notify_list(new_session)
        |> push_status_message(
          gettext("Removed %{nickname} from notify list", nickname: nick),
          :system
        )

      {:error, :not_found} ->
        push_status_message(
          socket,
          gettext("%{nickname} is not in your notify list", nickname: nick),
          :system
        )
    end
  end

  def handle_ui_action(socket, :notify_edit, %{nickname: nick, note: note}) do
    session = socket.assigns.session

    case NotifyList.update_note(session.notify_list, nick, note) do
      {:ok, updated_list} ->
        new_session = Session.set_notify_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_notify_list(new_session)
        |> push_status_message(gettext("Updated note for %{nickname}", nickname: nick), :system)

      {:error, :not_found} ->
        push_status_message(
          socket,
          gettext("%{nickname} is not in your notify list", nickname: nick),
          :system
        )
    end
  end

  def handle_ui_action(socket, :notify_list_display, _payload) do
    session = socket.assigns.session
    entries = NotifyList.sorted_entries(session.notify_list)

    if entries == [] do
      push_status_message(socket, gettext("Your notify list is empty"), :system)
    else
      Enum.reduce(entries, socket, fn entry, acc ->
        push_status_message(acc, format_notify_entry(entry), :system)
      end)
    end
  end

  defp format_notify_entry(entry) do
    status = if entry.online, do: gettext("online"), else: gettext("offline")
    note = if entry.note, do: gettext(" - %{note}", note: entry.note), else: ""

    gettext("  %{nickname} [%{status}]%{note}",
      nickname: entry.tracked_nickname,
      status: status,
      note: note
    )
  end

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
end
