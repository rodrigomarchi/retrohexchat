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
  alias RetroHexChat.Presence.NotifyList
  alias RetroHexChatWeb.ChatLive.{NotifyEvents, NotifyOps}

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :open_notify_list, _payload) do
    NotifyEvents.open(socket)
  end

  def handle_ui_action(socket, :notify_add, %{nickname: nick, note: note}) do
    session = socket.assigns.session

    case NotifyList.add_entry(session.notify_list, Session.owner(session), nick, note) do
      {:ok, updated_list} ->
        updated_list = NotifyOps.sync_entry_online(updated_list, nick)
        new_session = Session.set_notify_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_notify_list(new_session)
        |> push_status_message(
          dgettext("chat", "Added %{nickname} to notify list", nickname: nick),
          :system
        )

      {:error, :self_add} ->
        push_status_message(
          socket,
          dgettext("chat", "Cannot add yourself to the notify list"),
          :system
        )

      {:error, :duplicate} ->
        push_status_message(
          socket,
          dgettext("chat", "%{nickname} is already in your notify list", nickname: nick),
          :system
        )

      {:error, :list_full} ->
        push_status_message(
          socket,
          dgettext("chat", "Notify list is full (max 50 entries)"),
          :system
        )
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
          dgettext("chat", "Removed %{nickname} from notify list", nickname: nick),
          :system
        )

      {:error, :not_found} ->
        push_status_message(
          socket,
          dgettext("chat", "%{nickname} is not in your notify list", nickname: nick),
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
        |> push_status_message(
          dgettext("chat", "Updated note for %{nickname}", nickname: nick),
          :system
        )

      {:error, :not_found} ->
        push_status_message(
          socket,
          dgettext("chat", "%{nickname} is not in your notify list", nickname: nick),
          :system
        )
    end
  end

  def handle_ui_action(socket, :notify_list_display, _payload) do
    session = socket.assigns.session
    entries = NotifyList.sorted_entries(session.notify_list)

    if entries == [] do
      push_status_message(socket, dgettext("chat", "Your notify list is empty"), :system)
    else
      Enum.reduce(entries, socket, fn entry, acc ->
        push_status_message(acc, format_notify_entry(entry), :system)
      end)
    end
  end

  defp format_notify_entry(entry) do
    status = if entry.online, do: dgettext("chat", "online"), else: dgettext("chat", "offline")
    note = if entry.note, do: dgettext("chat", " - %{note}", note: entry.note), else: ""

    dgettext("chat", "  %{nickname} [%{status}]%{note}",
      nickname: entry.tracked_nickname,
      status: status,
      note: note
    )
  end
end
