defmodule RetroHexChatWeb.ChatLive.UiActions.Settings do
  @moduledoc """
  Settings UI actions: notice routing, bio management, whowas.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [stream_insert: 3]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [system_message: 1, show_whowas_text: 2, safe_update_bio: 3]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{NoticeRouting, UserBio}

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :show_whowas_info, %{nickname: target}),
    do: show_whowas_text(socket, target)

  def handle_ui_action(socket, :notice_routing_show, _payload) do
    session = socket.assigns.session
    routing = Session.get_notice_routing(session)

    stream_insert(
      socket,
      :chat_messages,
      system_message("* Notice routing is set to: #{routing}")
    )
  end

  def handle_ui_action(socket, :notice_routing_set, %{routing: routing}) do
    session = socket.assigns.session
    new_session = Session.set_notice_routing(session, routing)

    if new_session.identified do
      Task.start(fn ->
        NoticeRouting.save(new_session.nickname, %{routing: routing})
      end)
    end

    socket
    |> assign(session: new_session)
    |> stream_insert(
      :chat_messages,
      system_message("* Notice routing set to: #{routing}")
    )
  end

  def handle_ui_action(socket, :set_bio, %{text: text, truncated: truncated}) do
    session = socket.assigns.session
    new_session = Session.set_bio(session, text)

    if session.identified do
      UserBio.save(session.nickname, text)
    end

    Enum.each(session.channels, fn channel ->
      safe_update_bio("channel:#{channel}", session.nickname, text)
    end)

    msg =
      if truncated,
        do: "Bio truncated to 200 characters and set.",
        else: "Bio set: #{text}"

    socket
    |> assign(session: new_session)
    |> stream_insert(:chat_messages, system_message("* #{msg}"))
  end

  def handle_ui_action(socket, :view_bio, _payload) do
    session = socket.assigns.session

    msg =
      case Session.get_bio(session) do
        nil -> "No bio set. Use /bio <text> to set one."
        bio -> "Your bio: #{bio}"
      end

    stream_insert(socket, :chat_messages, system_message("* #{msg}"))
  end

  def handle_ui_action(socket, :clear_bio, _payload) do
    session = socket.assigns.session
    new_session = Session.set_bio(session, nil)

    if session.identified do
      UserBio.delete(session.nickname)
    end

    Enum.each(session.channels, fn channel ->
      safe_update_bio("channel:#{channel}", session.nickname, nil)
    end)

    socket
    |> assign(session: new_session)
    |> stream_insert(:chat_messages, system_message("* Bio cleared."))
  end
end
