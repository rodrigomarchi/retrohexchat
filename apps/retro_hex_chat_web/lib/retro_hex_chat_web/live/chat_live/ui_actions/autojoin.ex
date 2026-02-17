defmodule RetroHexChatWeb.ChatLive.UiActions.Autojoin do
  @moduledoc """
  Auto-join list UI actions: add, remove, clear, list display.
  """

  import Phoenix.Component, only: [assign: 2]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [system_event: 2, error_event: 2, maybe_persist_autojoin_list: 2]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.AutoJoinList

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :autojoin_list_display, _payload) do
    session = socket.assigns.session
    entries = AutoJoinList.entries(session.autojoin_list)

    if entries == [] do
      system_event(socket, "Your auto-join list is empty")
    else
      Enum.reduce(entries, socket, fn entry, acc ->
        system_event(acc, format_autojoin_entry(entry))
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
        |> system_event("* Added to auto-join list: #{channel}")

      {:error, reason} ->
        error_event(socket, "Failed to add auto-join channel: #{reason}")
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
        |> system_event("* Removed #{channel} from auto-join list")

      {:error, :not_found} ->
        error_event(socket, "#{channel} is not in your auto-join list")
    end
  end

  def handle_ui_action(socket, :autojoin_clear, _payload) do
    session = socket.assigns.session
    {:ok, updated_list} = AutoJoinList.clear(session.autojoin_list)
    new_session = Session.set_autojoin_list(session, updated_list)

    socket
    |> assign(session: new_session)
    |> maybe_persist_autojoin_list(new_session)
    |> system_event("* Auto-join list cleared")
  end

  defp format_autojoin_entry(entry) do
    key_part = if entry.channel_key, do: " (key: ****)", else: ""
    "  #{entry.channel_name}#{key_part}"
  end
end
