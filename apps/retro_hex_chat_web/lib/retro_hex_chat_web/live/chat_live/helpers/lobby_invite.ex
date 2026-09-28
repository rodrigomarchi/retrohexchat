defmodule RetroHexChatWeb.ChatLive.Helpers.LobbyInvite do
  @moduledoc """
  Sending a P2P invite, which is the same act as creating the session.

  The invite is a real private message: it sends a request line into the PM,
  notifies the target, switches the sender to that conversation, and the
  message carries the session's own address so the line is followable by
  whoever reads it later.

  Nobody is put inside anything by sending it. The card in the conversation is
  the door, for the person who asked exactly as much as for the person who was
  asked — which is what makes a session something you *go to*, in a tab of its
  own, instead of something that opens on top of the chat you were reading.

  Asking again for a session the two of them already have is not a second
  session and never was. It used to be a refusal in the sender's own words; it
  is now that session's card put back at the bottom of the conversation, which
  is the rule `CardDoor` holds for every room in this product.
  """

  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Lobby
  alias RetroHexChatWeb.ChatLive.Helpers.{CardDoor, Messages, PM}
  alias RetroHexChatWeb.ChatLive.P2PReadModel

  @spec handle_lobby_invite(Phoenix.LiveView.Socket.t(), map(), map()) ::
          Phoenix.LiveView.Socket.t()
  def handle_lobby_invite(socket, session, payload),
    do: deliver_invite(socket, session, payload)

  @doc """
  Sends the invite PM and opens the conversation the card lands in.
  """
  @spec deliver_invite(Phoenix.LiveView.Socket.t(), map(), map()) ::
          Phoenix.LiveView.Socket.t()
  def deliver_invite(socket, session, %{token: token} = payload) when is_binary(token) do
    do_deliver_invite(socket, session, payload)
  end

  def deliver_invite(socket, session, %{creator_id: creator_id, target_id: target_id} = payload) do
    case Lobby.active_session_between(creator_id, target_id) do
      %{token: token} -> do_deliver_invite(socket, session, Map.put(payload, :token, token))
      nil -> create_session(socket, session, payload)
    end
  end

  def deliver_invite(socket, _session, _payload) do
    Messages.system_event(socket, dgettext("chat", "Could not start the P2P invite."))
  end

  defp create_session(socket, session, %{creator_id: creator_id, target_id: target_id} = payload) do
    case Lobby.create_session(creator_id, target_id) do
      {:ok, %{token: token}} ->
        do_deliver_invite(socket, session, Map.put(payload, :token, token))

      {:error, message} ->
        Messages.system_event(socket, message)
    end
  end

  defp do_deliver_invite(socket, session, payload) do
    %{target: target, token: token} = payload

    outcome =
      CardDoor.deliver(
        {:pm, session.nickname, target},
        "/p2p/" <> token,
        lobby_invite_content(token),
        type: "p2p_invite"
      )

    socket
    |> PM.open_pm_conversation(target)
    |> P2PReadModel.refresh_pm(target)
    |> Messages.system_event(confirmation(outcome, target))
    |> push_event("scroll_to_bottom", %{})
  end

  defp confirmation(:posted, target),
    do:
      dgettext("chat", "P2P request sent to %{target}. Open it from the card below.",
        target: target
      )

  defp confirmation(:already_there, target),
    do:
      dgettext(
        "chat",
        "You already have a P2P session with %{target}. Its card is the line below.",
        target: target
      )

  @spec lobby_invite_content(String.t()) :: String.t()
  def lobby_invite_content(token),
    do:
      dgettext("chat", "P2P session request. Open it from the card below. /p2p/%{token}",
        token: token
      )
end
