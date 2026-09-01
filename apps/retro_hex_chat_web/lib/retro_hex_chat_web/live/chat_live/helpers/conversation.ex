defmodule RetroHexChatWeb.ChatLive.Helpers.Conversation do
  @moduledoc """
  Bringing a conversation on screen, and describing who is in it.

  A channel and a private conversation occupy the same region, the same tab, the
  same composer and the same user list, and switching to either has to leave the
  session in the same shape: the conversation marked read, the composer out of
  whatever mode the last one put it in, the search bar closed, the mobile drawers
  out of the way. That sequence was written twice — once for the click path and
  once for the keyboard/window-cycling path — and the copies had already drifted,
  so cycling windows with the keyboard kept a stale composer mode and an open
  search bar that clicking a tab did not.

  `load_roster/1` is the other half: it asks `RetroHexChat.Chat.Roster` who is in
  whichever conversation is now active and hands the answer to the one user-list
  island, so a private conversation stops inheriting the last channel's members.
  The parent stays the canonical owner of `conversation_members` — tab-complete
  and the context menus read the materialized list from there.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [send_update: 2]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.Roster
  alias RetroHexChat.Chat.UnreadTracker
  alias RetroHexChatWeb.ChatLive
  alias RetroHexChatWeb.ChatLive.Components.Composer
  alias RetroHexChatWeb.ChatLive.Components.Nicklist
  alias RetroHexChatWeb.ChatLive.Helpers.Channel, as: ChannelHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.PM
  alias RetroHexChatWeb.ChatLive.Helpers.Session, as: SessionHelpers
  alias RetroHexChatWeb.ChatLive.ShareCards

  @doc """
  Switches to a channel this session has already joined.

  Joining one that is not open yet is `Helpers.Channel.join_channel/3` — this is
  the path for a conversation that is already there.
  """
  @spec activate_channel(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def activate_channel(socket, channel) when is_binary(channel) do
    session = Session.set_active_channel(socket.assigns.session, channel)

    socket
    |> enter_conversation(session, channel)
    |> load_roster()
    |> ChannelHelpers.load_channel_messages_with_pagination(channel)
    |> SessionHelpers.push_reconnect_state()
  end

  @doc "Switches to a private conversation, opening its tab if it was closed."
  @spec activate_pm(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def activate_pm(socket, nickname) when is_binary(nickname) do
    session =
      socket.assigns.session
      |> Session.add_pm_conversation(nickname)
      |> Session.set_active_pm(nickname)

    socket
    |> PM.open_pm_tab(nickname)
    |> enter_conversation(session, "pm:#{nickname}")
    |> load_roster()
    |> PM.load_pm_messages_with_pagination(nickname)
    |> SessionHelpers.push_reconnect_state()
  end

  @doc """
  Loads the roster of whatever conversation is active and feeds the user list.

  Called wherever the active conversation changes or its membership does. The
  status tab has no roster of its own: it keeps the last conversation's, because
  the session still points at it and the user list is hidden while it is up.
  """
  @spec load_roster(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def load_roster(socket) do
    case target(socket.assigns.session) do
      nil -> reset_roster(socket)
      target -> apply_roster(socket, Roster.of(target))
    end
  end

  @doc "The conversation the session is pointing at, as `Roster.of/1` addresses it."
  @spec target(Session.t()) :: Roster.target() | nil
  def target(%Session{active_pm: peer, nickname: viewer})
      when is_binary(peer) and peer != "" and is_binary(viewer),
      do: {:private, viewer, peer}

  def target(%Session{active_channel: channel}) when is_binary(channel) and channel != "",
    do: {:channel, channel}

  def target(%Session{}), do: nil

  @doc """
  Whether `nick` is one of the two people in the private conversation on screen.

  What makes a presence change worth acting on: the server-wide topic carries
  everybody's, and only the handful about this conversation change what is
  rendered.
  """
  @spec active_private_participant?(Session.t(), String.t()) :: boolean()
  def active_private_participant?(%Session{active_pm: peer, nickname: viewer}, nick)
      when is_binary(peer) and is_binary(nick) do
    same_nick?(nick, peer) or same_nick?(nick, viewer)
  end

  def active_private_participant?(_session, _nick), do: false

  @doc """
  Replaces the materialized roster with `members`, keeping the user list in step.

  For a membership delta the caller already computed — a join, a part, a role or
  away change — rather than re-reading the whole conversation.
  """
  @spec put_members(Phoenix.LiveView.Socket.t(), [Roster.member()]) ::
          Phoenix.LiveView.Socket.t()
  def put_members(socket, members) do
    socket
    |> assign(conversation_members: members)
    |> Nicklist.reset(members)
    # A reset rebuilds every row, so the conference marker has to be said
    # again: the rows that carried it are gone.
    |> ShareCards.refresh()
  end

  @doc "Drops the mobile drawers, which overlay the conversation rather than sitting beside it."
  @spec close_mobile_panels(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def close_mobile_panels(%{assigns: %{mobile_viewport: true}} = socket) do
    assign(socket, show_conversations: false, show_nicklist: false)
  end

  def close_mobile_panels(socket), do: socket

  # Everything a conversation switch owes the session, whichever kind it is.
  @spec enter_conversation(Phoenix.LiveView.Socket.t(), Session.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  defp enter_conversation(socket, session, unread_key) do
    if socket.assigns[:pm_typing_timer], do: Process.cancel_timer(socket.assigns.pm_typing_timer)

    socket
    |> assign(
      session: session,
      notice_active: false,
      unread_counts: UnreadTracker.reset(socket.assigns.unread_counts, unread_key),
      highlight_channels: MapSet.delete(socket.assigns.highlight_channels, unread_key),
      flash_channels: MapSet.delete(socket.assigns.flash_channels, unread_key),
      show_status_tab: false,
      channel_view: :chat,
      pm_typing_from: nil,
      pm_typing_timer: nil
    )
    |> reset_composer_modes()
    |> close_search()
    |> close_mobile_panels()
  end

  @spec apply_roster(Phoenix.LiveView.Socket.t(), Roster.t()) :: Phoenix.LiveView.Socket.t()
  defp apply_roster(socket, %Roster{kind: :channel} = roster) do
    socket
    |> assign(current_topic: roster.topic, current_modes: roster.modes)
    |> put_members(roster.members)
  end

  defp apply_roster(socket, %Roster{} = roster) do
    socket
    |> assign(current_topic: nil, current_modes: nil)
    |> put_members(roster.members)
  end

  @spec reset_roster(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp reset_roster(socket) do
    socket
    |> assign(current_topic: nil, current_modes: nil)
    |> put_members([])
  end

  defp reset_composer_modes(socket) do
    send_update(Composer, id: Composer.id(), reset_modes: true)
    socket
  end

  defp same_nick?(left, right) when is_binary(left) and is_binary(right),
    do: String.downcase(left) == String.downcase(right)

  defp same_nick?(_left, _right), do: false

  defp close_search(socket) do
    if socket.assigns[:search_visible] do
      ChatLive.SearchEvents.close(socket)
    else
      socket
    end
  end
end
