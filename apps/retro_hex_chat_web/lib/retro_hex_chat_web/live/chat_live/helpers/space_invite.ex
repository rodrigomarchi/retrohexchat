defmodule RetroHexChatWeb.ChatLive.Helpers.SpaceInvite do
  @moduledoc """
  Publishes the virtual-space invite card after a successful `/space` command.

  Unlike the P2P lobby invite (a PM), the space invite is a persisted CHANNEL
  message of type `space_invite`: everyone in the channel sees the card, and
  it stays in the history rendering the session's current state. The content
  carries the textual `/space/<token>` fallback for clients that cannot
  resolve the card.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.Service
  alias RetroHexChatWeb.ChatLive.Helpers.Messages

  @spec handle_space_invite(Phoenix.LiveView.Socket.t(), map(), map()) ::
          Phoenix.LiveView.Socket.t()
  def handle_space_invite(socket, session, payload) do
    case publish_invite(session.nickname, payload) do
      {:ok, _message} ->
        Messages.system_event(
          socket,
          dgettext("chat", "Virtual space created in %{channel}.", channel: payload.target)
        )

      {:error, reason} ->
        Messages.error_event(
          socket,
          dgettext("chat", "Space created, but the invite could not be posted: %{reason}",
            reason: to_string(reason)
          )
        )
    end
  end

  @spec publish_invite(String.t(), map()) ::
          {:ok, RetroHexChat.Chat.Message.t()} | {:error, String.t()}
  def publish_invite(nickname, payload) do
    Service.send_message(payload.target, nickname, invite_content(payload.token), "space_invite")
  end

  @spec invite_content(String.t()) :: String.t()
  def invite_content(token),
    do: dgettext("chat", "Virtual space ready. Enter the space: /space/%{token}", token: token)
end
