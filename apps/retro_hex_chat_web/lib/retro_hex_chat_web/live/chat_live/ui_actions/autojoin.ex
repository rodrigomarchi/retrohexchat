defmodule RetroHexChatWeb.ChatLive.UiActions.Autojoin do
  @moduledoc """
  Auto-join list UI actions: add, remove, clear, list display.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [stream_insert: 3]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [system_message: 1, error_message: 1, maybe_persist_autojoin_list: 2]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.AutoJoinList

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :autojoin_list_display, _payload) do
    session = socket.assigns.session
    entries = AutoJoinList.entries(session.autojoin_list)

    if entries == [] do
      stream_insert(socket, :chat_messages, system_message("Your auto-join list is empty"))
    else
      Enum.reduce(entries, socket, fn entry, acc ->
        stream_insert(acc, :chat_messages, system_message(format_autojoin_entry(entry)))
      end)
    end
  end

  def handle_ui_action(socket, :autojoin_add, %{channel: channel} = payload) do
    session = socket.assigns.session
    key = Map.get(payload, :key)

    case AutoJoinList.add_entry(session.autojoin_list, channel, key) do
      {:ok, updated_list} ->
        new_session = Session.set_autojoin_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_autojoin_list(new_session)
        |> stream_insert(
          :chat_messages,
          system_message("* Added to auto-join list: #{channel}")
        )

      {:error, reason} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Failed to add auto-join channel: #{reason}")
        )
    end
  end

  def handle_ui_action(socket, :autojoin_remove, %{channel: channel}) do
    session = socket.assigns.session

    case AutoJoinList.remove_entry(session.autojoin_list, channel) do
      {:ok, updated_list} ->
        new_session = Session.set_autojoin_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_autojoin_list(new_session)
        |> stream_insert(
          :chat_messages,
          system_message("* Removed #{channel} from auto-join list")
        )

      {:error, :not_found} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("#{channel} is not in your auto-join list")
        )
    end
  end

  def handle_ui_action(socket, :autojoin_clear, _payload) do
    session = socket.assigns.session
    {:ok, updated_list} = AutoJoinList.clear(session.autojoin_list)
    new_session = Session.set_autojoin_list(session, updated_list)

    socket
    |> assign(session: new_session)
    |> maybe_persist_autojoin_list(new_session)
    |> stream_insert(:chat_messages, system_message("* Auto-join list cleared"))
  end

  defp format_autojoin_entry(entry) do
    key_part = if entry.channel_key, do: " (key: ****)", else: ""
    "  #{entry.channel_name}#{key_part}"
  end
end
