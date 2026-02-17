defmodule RetroHexChatWeb.ChatLive.UiActions.Ignore do
  @moduledoc """
  Ignore list UI actions: add, remove, list display.
  """

  import Phoenix.Component, only: [assign: 2]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      system_event: 2,
      error_event: 2,
      maybe_persist_ignore_list: 2,
      cancel_ignore_timer: 2,
      maybe_start_ignore_timer: 3,
      cancel_auto_ignore_with_cooldown: 2
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{IgnoreEntry, IgnoreList}
  alias RetroHexChat.Services.RegisteredNick

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :ignore_list, _payload) do
    session = socket.assigns.session
    entries = IgnoreList.sorted_entries(session.ignore_list)

    if entries == [] do
      system_event(socket, "Your ignore list is empty")
    else
      Enum.reduce(entries, socket, fn entry, acc ->
        system_event(acc, format_ignore_entry(entry))
      end)
    end
  end

  def handle_ui_action(socket, :ignore_add, %{nickname: nick, type: type} = payload) do
    session = socket.assigns.session
    duration = Map.get(payload, :duration)
    expires_at = if duration, do: DateTime.add(DateTime.utc_now(), duration, :second)
    existing = IgnoreList.get_entry(session.ignore_list, nick)

    case IgnoreList.add_entry(session.ignore_list, nick, type, expires_at) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        msg =
          if existing do
            "* #{nick} ignore updated to: #{type}"
          else
            "* #{nick} is now ignored (#{type})"
          end

        close_p2p_sessions_for_ignore(socket, nick)

        socket
        |> assign(session: new_session)
        |> cancel_ignore_timer(nick)
        |> maybe_start_ignore_timer(nick, duration)
        |> maybe_persist_ignore_list(new_session)
        |> system_event(msg)

      {:error, :list_full} ->
        error_event(socket, "Ignore list is full (max 100 entries)")

      {:error, :invalid_type} ->
        error_event(socket, "Invalid ignore type: #{type}")
    end
  end

  def handle_ui_action(socket, :ignore_remove, %{nickname: nick}) do
    session = socket.assigns.session

    case IgnoreList.remove_entry(session.ignore_list, nick) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> cancel_ignore_timer(nick)
        |> cancel_auto_ignore_with_cooldown(nick)
        |> maybe_persist_ignore_list(new_session)
        |> system_event("* #{nick} is no longer ignored")

      {:error, :not_found} ->
        error_event(socket, "#{nick} is not in your ignore list")
    end
  end

  defp format_ignore_entry(entry) do
    expires = if IgnoreEntry.permanent?(entry), do: "permanent", else: "timed"
    "  #{entry.nickname} [#{entry.ignore_type}] (#{expires})"
  end

  defp close_p2p_sessions_for_ignore(socket, ignored_nick) do
    owner_nick = socket.assigns.session.nickname

    with %{id: owner_id} <- RetroHexChat.Repo.get_by(RegisteredNick, nickname: owner_nick),
         %{id: ignored_id} <- RetroHexChat.Repo.get_by(RegisteredNick, nickname: ignored_nick) do
      RetroHexChat.P2P.close_sessions_between(owner_id, ignored_id)
    end
  end
end
