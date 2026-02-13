defmodule RetroHexChatWeb.ChatLive.UiActions.Notify do
  @moduledoc """
  Notify list UI actions: add, remove, edit, list display, open dialog.
  """

  import Phoenix.Component, only: [assign: 2]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      push_status_message: 3,
      maybe_persist_notify_list: 2
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Presence.NotifyList

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :open_notify_list, _payload) do
    assign(socket, show_notify_list: true)
  end

  def handle_ui_action(socket, :notify_add, %{nickname: nick, note: note}) do
    session = socket.assigns.session

    case NotifyList.add_entry(session.notify_list, session.nickname, nick, note) do
      {:ok, updated_list} ->
        new_session = Session.set_notify_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_notify_list(new_session)
        |> push_status_message("Added #{nick} to notify list", :system)

      {:error, :self_add} ->
        push_status_message(socket, "Cannot add yourself to the notify list", :system)

      {:error, :duplicate} ->
        push_status_message(socket, "#{nick} is already in your notify list", :system)

      {:error, :list_full} ->
        push_status_message(socket, "Notify list is full (max 50 entries)", :system)
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
        |> push_status_message("Removed #{nick} from notify list", :system)

      {:error, :not_found} ->
        push_status_message(socket, "#{nick} is not in your notify list", :system)
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
        |> push_status_message("Updated note for #{nick}", :system)

      {:error, :not_found} ->
        push_status_message(socket, "#{nick} is not in your notify list", :system)
    end
  end

  def handle_ui_action(socket, :notify_list_display, _payload) do
    session = socket.assigns.session
    entries = NotifyList.sorted_entries(session.notify_list)

    if entries == [] do
      push_status_message(socket, "Your notify list is empty", :system)
    else
      Enum.reduce(entries, socket, fn entry, acc ->
        push_status_message(acc, format_notify_entry(entry), :system)
      end)
    end
  end

  defp format_notify_entry(entry) do
    status = if entry.online, do: "online", else: "offline"
    note = if entry.note, do: " - #{entry.note}", else: ""
    "  #{entry.tracked_nickname} [#{status}]#{note}"
  end
end
