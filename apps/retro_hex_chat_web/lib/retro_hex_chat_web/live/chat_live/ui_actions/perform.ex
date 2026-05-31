defmodule RetroHexChatWeb.ChatLive.UiActions.Perform do
  @moduledoc """
  Perform list UI actions: add, remove, move, clear, list display, open dialog.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [system_event: 2, error_event: 2, maybe_persist_perform_list: 2]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.PerformList

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :open_perform_dialog, payload) do
    tab = Map.get(payload, :tab, "commands")
    assign(socket, show_perform_dialog: true, perform_dialog_tab: tab)
  end

  def handle_ui_action(socket, :perform_list_display, _payload) do
    session = socket.assigns.session
    entries = PerformList.entries(session.perform_list)

    if entries == [] do
      system_event(socket, dgettext("chat", "Your perform list is empty"))
    else
      Enum.with_index(entries)
      |> Enum.reduce(socket, fn {entry, idx}, acc ->
        masked = PerformList.mask_command(entry.command)
        system_event(acc, dgettext("chat", "  %{index}: %{command}", index: idx, command: masked))
      end)
    end
  end

  def handle_ui_action(socket, :perform_add, %{command: command}) do
    session = socket.assigns.session

    case PerformList.add_entry(session.perform_list, command) do
      {:ok, updated_list} ->
        new_session = Session.set_perform_list(session, updated_list)
        masked = PerformList.mask_command(String.trim(command))

        socket
        |> assign(session: new_session)
        |> maybe_persist_perform_list(new_session)
        |> system_event(dgettext("chat", "* Added to perform list: %{command}", command: masked))

      {:error, :invalid_command} ->
        error_event(socket, dgettext("chat", "Invalid command. Commands must start with /"))

      {:error, :disallowed_command} ->
        error_event(socket, dgettext("chat", "That command cannot be added to the perform list"))

      {:error, :command_too_long} ->
        error_event(socket, dgettext("chat", "Command too long (max 500 characters)"))

      {:error, :list_full} ->
        error_event(socket, dgettext("chat", "Perform list is full (max 50 commands)"))
    end
  end

  def handle_ui_action(socket, :perform_remove, %{position: position}) do
    session = socket.assigns.session

    case PerformList.remove_entry(session.perform_list, position) do
      {:ok, updated_list} ->
        new_session = Session.set_perform_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_perform_list(new_session)
        |> system_event(
          dgettext("chat", "* Removed command at position %{position}", position: position)
        )

      {:error, :not_found} ->
        error_event(
          socket,
          dgettext("chat", "No command at position %{position}", position: position)
        )
    end
  end

  def handle_ui_action(socket, :perform_move, %{from: from, to: to}) do
    session = socket.assigns.session

    case PerformList.move_entry(session.perform_list, from, to) do
      {:ok, updated_list} ->
        new_session = Session.set_perform_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_perform_list(new_session)
        |> system_event(
          dgettext("chat", "* Moved command from position %{from} to %{to}", from: from, to: to)
        )

      {:error, :same_position} ->
        error_event(socket, dgettext("chat", "Source and destination are the same"))

      {:error, :invalid_position} ->
        error_event(socket, dgettext("chat", "Invalid position"))
    end
  end

  def handle_ui_action(socket, :perform_clear, _payload) do
    session = socket.assigns.session
    {:ok, updated_list} = PerformList.clear(session.perform_list)
    new_session = Session.set_perform_list(session, updated_list)

    socket
    |> assign(session: new_session)
    |> maybe_persist_perform_list(new_session)
    |> system_event(dgettext("chat", "* Perform list cleared"))
  end
end
