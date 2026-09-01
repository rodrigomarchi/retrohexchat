defmodule RetroHexChatWeb.ChatLive.GroupCallEvents do
  @moduledoc """
  The chat's side of a conference that does not live here.

  A conference has one door, and it is a card in the conversation.
  `RetroHexChatWeb.App.CallLive` owns everything about being inside one, at an
  address of its own, in a tab of its own. What is left here is the act that
  creates the room and writes the card, and nothing else:

    * **which channel.** "Call" is a button on a conversation, so the chat is
      what knows which conversation you are looking at, and what refuses when
      it is a private one.
    * **minting the address, once.** Opening creates the room; the room's
      address is written into the channel as a message everyone can see and
      scroll back to. A channel that already has a live room gets neither a
      second room nor a second card.
    * **saying what happened.** A refusal belongs in the conversation, which is
      where every other refusal in this product appears.

  What the chat keeps about a call is only what its own chrome draws — which
  channel, how many are inside, and whether this person has that address open
  somewhere. That is `RetroHexChatWeb.ChatLive.GroupCallReadModel`, fed by the
  channel's own conference broadcasts, and it needs no call process of its own.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Chat.Service, as: ChatService
  alias RetroHexChat.GroupCall
  alias RetroHexChat.ShareLinks
  alias RetroHexChat.Topics
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.ChatLive.GroupCallReadModel
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ShareLinkRef

  @type event_result :: {:cont | :halt, Socket.t()}

  @doc """
  Rebuild what the chat knows about calls, after a mount or a reconnect.

  Every channel gets its badge back. There is nothing else to restore: a call
  this person is in is a tab of their own, and a reload of the chat neither
  ends it nor has to reopen it.
  """
  @spec rehydrate(Socket.t()) :: Socket.t()
  def rehydrate(
        %{assigns: %{session: %{nickname: nickname, channels: channels, identified: true}}} =
          socket
      )
      when is_binary(nickname) and is_list(channels) do
    GroupCallReadModel.refresh_all(socket)
  end

  def rehydrate(socket), do: socket

  @doc """
  Leave a channel's call when the channel itself leaves the session.

  A kick or a `/part` is not a tab being closed: the call has lost the
  membership it stood on, so the seat goes even though the screen holding it is
  somewhere this process cannot reach. The domain is asked directly, which is
  the only way left now that the call is not a child of the chat.
  """
  @spec leave_channel_call(Socket.t(), String.t(), String.t()) :: Socket.t()
  def leave_channel_call(%{assigns: %{session: %{nickname: nickname}}} = socket, channel, reason)
      when is_binary(nickname) do
    case seat_in(socket, channel, nickname) do
      {token, participant_id} -> _ = GroupCall.leave_call(token, participant_id, reason)
      nil -> :ok
    end

    # The seat is the domain's and the screen is somewhere this process cannot
    # reach, so the screen is told on the room's own topic — the one the call
    # is already listening to, and the only one carrying nothing else.
    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      Topics.channel_calls(channel),
      {:channel_membership_lost, %{channel: channel, nickname: nickname, reason: reason}}
    )

    socket
  end

  def leave_channel_call(socket, _channel_name, _reason), do: socket

  @spec handle_event(String.t(), map(), Socket.t()) :: event_result()
  def handle_event("group_call_open", _params, socket) do
    {:halt, open_conference(socket)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # Opening is two things that must not come apart: the room, and the address
  # of the room written where people are reading. A room created without its
  # card would be a conference nobody has a way into.
  defp open_conference(socket) do
    with {:ok, channel} <- active_channel(socket),
         :ok <- require_identified(socket),
         {:ok, user_id} <- SessionHelpers.resolve_user_id(socket.assigns.session.nickname),
         actor = %{user_id: user_id, nickname: socket.assigns.session.nickname},
         {:ok, room} <- GroupCall.get_or_create_channel_call(channel, actor) do
      socket
      |> announce(room, channel, actor)
      |> GroupCallReadModel.refresh(channel)
    else
      {:redirect, nil} ->
        Messages.error_event(
          socket,
          dgettext("group_call", "You must be registered with NickServ to use group calls.")
        )

      {:error, message} ->
        Messages.error_event(socket, message)
    end
  end

  # A room that was already running keeps the card it was opened with. Saying so
  # is transient on purpose — it answers the click, and the durable answer is
  # the card that is already in the conversation.
  defp announce(socket, %{created?: false}, channel, _actor) do
    Messages.system_event(
      socket,
      dgettext(
        "group_call",
        "A conference is already open in %{channel}. Its card is in this conversation.",
        channel: channel
      )
    )
  end

  defp announce(socket, %{token: token}, channel, actor) do
    case ShareLinks.create(%{
           kind: "call",
           target: %{"room_token" => token},
           creator_id: actor.user_id,
           creator_nick: actor.nickname
         }) do
      {:ok, link} ->
        _ =
          ChatService.send_system_message(
            channel,
            dgettext("group_call", "%{nickname} opened a conference — %{url}",
              nickname: actor.nickname,
              url: ShareLinkRef.url(link.slug)
            )
          )

        socket

      {:error, _reason} ->
        Messages.error_event(
          socket,
          dgettext("group_call", "The conference opened, but its link could not be created.")
        )
    end
  end

  # The room and the seat in it, for a channel this person may not be sitting
  # in at all. Both halves are the domain's; the chat only supplies the name.
  defp seat_in(socket, channel, nickname) do
    with %{room: %{id: room_id, token: token}} when is_integer(room_id) <-
           GroupCallReadModel.summary(socket, channel),
         %{id: participant_id} <- GroupCall.active_participant(room_id, nickname) do
      {token, participant_id}
    else
      _absent -> nil
    end
  end

  defp active_channel(%{assigns: %{show_status_tab: true}}),
    do: {:error, dgettext("group_call", "Open a channel before starting a group call.")}

  defp active_channel(%{assigns: %{session: %{active_pm: pm}}}) when is_binary(pm),
    do: {:error, dgettext("group_call", "Group calls are available in channels only.")}

  defp active_channel(%{assigns: %{session: %{active_channel: channel}}})
       when is_binary(channel) and channel != "",
       do: {:ok, channel}

  defp active_channel(_socket),
    do: {:error, dgettext("group_call", "Open a channel before starting a group call.")}

  defp require_identified(%{assigns: %{session: %{identified: true}}}), do: :ok

  defp require_identified(_socket),
    do:
      {:error, dgettext("group_call", "You must be identified with NickServ to use group calls.")}
end
