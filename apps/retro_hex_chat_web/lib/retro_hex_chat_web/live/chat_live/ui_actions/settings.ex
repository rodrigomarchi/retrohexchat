defmodule RetroHexChatWeb.ChatLive.UiActions.Settings do
  @moduledoc """
  Settings UI actions: notice routing, bio management, whowas.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [system_event: 2, show_whowas_text: 2, safe_update_bio: 3]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.UserBio

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :show_whowas_info, %{nickname: target}),
    do: show_whowas_text(socket, target)

  def handle_ui_action(socket, :notice_routing_show, _payload) do
    system_event(socket, dgettext("chat", "* Notice routing is hardcoded to: active"))
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
        do: dgettext("chat", "* Bio truncated to 200 characters and set."),
        else: dgettext("chat", "* Bio set: %{text}", text: text)

    socket
    |> assign(session: new_session)
    |> system_event(msg)
  end

  def handle_ui_action(socket, :view_bio, _payload) do
    session = socket.assigns.session

    msg =
      case Session.get_bio(session) do
        nil -> dgettext("chat", "* No bio set. Use /bio <text> to set one.")
        bio -> dgettext("chat", "* Your bio: %{bio}", bio: bio)
      end

    system_event(socket, msg)
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
    |> system_event(dgettext("chat", "* Bio cleared."))
  end
end
