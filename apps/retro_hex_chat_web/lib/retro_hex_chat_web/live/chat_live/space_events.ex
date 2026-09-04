defmodule RetroHexChatWeb.ChatLive.SpaceEvents do
  @moduledoc """
  Writing the door to this conversation's space into the conversation.

  A space is a place: nothing is created, its address is good whether anybody is
  standing in it or not, and for a long time the entry beside the tabs was that
  address as an anchor. That made two doors into one room — the anchor and the
  card — and the anchor was the one that skipped the conversation entirely, so
  the people who could have come never learned there was anywhere to come to.

  There is one door now, and it is the card. Pressing the entry mints the link
  and posts it; the card under the line is what anybody reading, including the
  person who pressed it, walks through.

  `ShareLinks.create/1` hands back the link that already exists for the same
  place and the same person, so pressing twice cannot scatter addresses. What
  the second press must not do is post the card twice, which is why an existing
  link answers with a sentence instead of another card.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  require Logger

  alias RetroHexChat.Chat.Service, as: ChatService
  alias RetroHexChat.ShareLinks
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.SpaceReadModel
  alias RetroHexChatWeb.ShareLinkRef

  @type event_result ::
          {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: event_result()
  def handle_event("space_open", _params, socket) do
    {:halt, announce_space(socket)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp announce_space(socket) do
    with %{} = space <- conversation_space(socket),
         {:ok, user_id} <- registered_user(socket) do
      post(socket, space, user_id)
    else
      nil ->
        socket

      :not_registered ->
        Messages.error_event(
          socket,
          dgettext("chat", "You must be registered with NickServ to open a space.")
        )
    end
  end

  defp post(socket, space, user_id) do
    nickname = socket.assigns.session.nickname
    target = %{"space_id" => space.space_id, "mode" => space.mode}

    if ShareLinks.find_open("space", target, user_id) do
      Messages.system_event(
        socket,
        dgettext("chat", "The space is already open here. Its card is in this conversation.")
      )
    else
      mint_and_write(socket, space, target, user_id, nickname)
    end
  end

  defp mint_and_write(socket, space, target, user_id, nickname) do
    case ShareLinks.create(%{
           kind: "space",
           target: target,
           creator_id: user_id,
           creator_nick: nickname
         }) do
      {:ok, link} ->
        write_card(socket, space, link, nickname)

      {:error, reason} ->
        Logger.warning("Space card failed: #{inspect(reason)}")

        Messages.error_event(
          socket,
          dgettext("chat", "The space could not be opened. Try again.")
        )
    end
  end

  # The line the card is drawn from. A channel hears it as the channel; the two
  # people in a private space hear it in the conversation they already have.
  defp write_card(socket, %{mode: "direct_message", participants: [_, _] = pair}, link, nickname) do
    peer = Enum.find(pair, &(String.downcase(&1) != String.downcase(nickname)))

    _ =
      ChatService.send_private_message(nickname, peer, content(nickname, link), "system")

    Messages.system_event(
      socket,
      dgettext("chat", "The space is open. Its card is in this conversation.")
    )
  end

  defp write_card(socket, space, link, nickname) do
    _ = ChatService.send_system_message(space.space_id, content(nickname, link))

    Messages.system_event(
      socket,
      dgettext("chat", "The space is open. Its card is in this conversation.")
    )
  end

  defp content(nickname, link) do
    dgettext("chat", "%{nickname} opened the space — %{url}",
      nickname: nickname,
      url: ShareLinkRef.url(link.slug)
    )
  end

  defp conversation_space(socket) do
    SpaceReadModel.conversation_space(
      socket.assigns.session,
      socket.assigns[:show_status_tab] || false
    )
  end

  defp registered_user(socket) do
    case SessionHelpers.resolve_user_id(socket.assigns.session.nickname || "") do
      {:ok, user_id} -> {:ok, user_id}
      _unavailable -> :not_registered
    end
  end
end
