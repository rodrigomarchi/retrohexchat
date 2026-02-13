defmodule RetroHexChatWeb.ChatLive.UiActions.Aliases do
  @moduledoc """
  Alias UI actions: add, remove, list display, open dialog.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [stream_insert: 3]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [system_message: 1, error_message: 1, maybe_persist_aliases: 2]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.AliasList

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :open_alias_dialog, _payload) do
    assign(socket, show_alias_dialog: true)
  end

  def handle_ui_action(socket, :alias_added, %{name: name, expansion: expansion}) do
    session = socket.assigns.session

    case AliasList.add_entry(session.aliases, name, expansion) do
      {:ok, updated_list} ->
        new_session = Session.set_aliases(session, updated_list)

        warning =
          if AliasList.shadows_builtin?(name), do: " (warning: shadows built-in /#{name})"

        socket
        |> assign(session: new_session)
        |> maybe_persist_aliases(new_session)
        |> stream_insert(
          :chat_messages,
          system_message("* Alias /#{name} created#{warning || ""}")
        )

      {:error, :duplicate_name} ->
        stream_insert(socket, :chat_messages, error_message("Alias /#{name} already exists"))

      {:error, :invalid_name} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Invalid alias name. Use only letters, numbers, hyphens, underscores.")
        )

      {:error, :expansion_too_long} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Expansion too long (max 500 characters)")
        )

      {:error, :command_chaining} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Expansion must not contain command chaining (|, &&, ;, newlines)")
        )

      {:error, :list_full} ->
        stream_insert(socket, :chat_messages, error_message("Alias list is full (max 50)"))
    end
  end

  def handle_ui_action(socket, :alias_removed, %{name: name}) do
    session = socket.assigns.session

    case AliasList.remove_entry(session.aliases, name) do
      {:ok, updated_list} ->
        new_session = Session.set_aliases(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_aliases(new_session)
        |> stream_insert(:chat_messages, system_message("* Alias /#{name} removed"))

      {:error, :not_found} ->
        stream_insert(socket, :chat_messages, error_message("Alias /#{name} not found"))
    end
  end

  def handle_ui_action(socket, :alias_list_display, _payload) do
    session = socket.assigns.session
    entries = AliasList.entries(session.aliases)

    if entries == [] do
      stream_insert(socket, :chat_messages, system_message("Your alias list is empty"))
    else
      Enum.reduce(entries, socket, fn entry, acc ->
        stream_insert(
          acc,
          :chat_messages,
          system_message("  /#{entry.name} → #{entry.expansion}")
        )
      end)
    end
  end
end
