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
      scroll back to. A channel that already has a live room gets no second
      room — pressing again puts that one room's card back at the bottom of the
      channel, which is the rule `CardDoor` holds for every room in the
      product.
    * **saying what happened.** A refusal belongs in the conversation, which is
      where every other refusal in this product appears.

  What the chat keeps about a call is only what its own chrome draws — which
  channel, how many are inside, and whether this person has that address open
  somewhere. That is `RetroHexChatWeb.ChatLive.GroupCallReadModel`, fed by the
  channel's own conference broadcasts, and it needs no call process of its own.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.GroupCall
  alias RetroHexChat.ShareLinks
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.ChatLive.GroupCallReadModel
  alias RetroHexChatWeb.ChatLive.Helpers.CardDoor
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

  # A room that was already running keeps the one card it was opened with, and
  # the press brings that card back down to where the reader is. The room is not
  # the thing somebody is looking for on a second press — the door is, and it
  # was thirty lines up.
  defp announce(socket, %{created?: false, token: token} = room, channel, actor) do
    case ShareLinks.find_open_for_target("call", %{"room_token" => token}) do
      nil -> mint_and_write(socket, room, channel, actor)
      link -> write_card(socket, channel, link, actor.nickname)
    end
  end

  defp announce(socket, room, channel, actor), do: mint_and_write(socket, room, channel, actor)

  defp mint_and_write(socket, %{token: token}, channel, actor) do
    case ShareLinks.create(%{
           kind: "call",
           target: %{"room_token" => token},
           creator_id: actor.user_id,
           creator_nick: actor.nickname
         }) do
      {:ok, link} ->
        write_card(socket, channel, link, actor.nickname)

      {:error, _reason} ->
        Messages.error_event(
          socket,
          dgettext("group_call", "The conference opened, but its link could not be created.")
        )
    end
  end

  defp write_card(socket, channel, link, nickname) do
    case CardDoor.deliver({:channel, channel}, "/join/" <> link.slug, content(nickname, link)) do
      :posted ->
        socket

      :already_there ->
        Messages.system_event(
          socket,
          dgettext(
            "group_call",
            "The conference in %{channel} is open. Its card is the line below.",
            channel: channel
          )
        )
    end
  end

  defp content(nickname, link) do
    dgettext("group_call", "%{nickname} opened a conference — %{url}",
      nickname: nickname,
      url: ShareLinkRef.url(link.slug)
    )
  end

  # The room and the seat in it, for a channel this person may not be sitting
  # in at all. Both halves are the domain's; the chat only supplies the name.
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
