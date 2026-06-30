defmodule RetroHexChatWeb.ChatLive.InviteEvents do
  @moduledoc """
  Resolve channel invite accept/ignore actions for the InviteQueueDialog island.

  The dialog (`Components.InviteQueueDialog`) renders the pending-invite queue and
  routes the Join/Ignore button clicks to itself (`@myself`); it bubbles the channel
  up to the parent LiveView, whose `handle_info` calls `accept/2` / `ignore/2` here.

  `pending_invites` stays parent-owned: it is the Escape-priority read-model
  (`keyboard_events` dismisses the topmost invite first) and the per-invite
  expiration timers fire into this LiveView process's `handle_info`. So the resolve
  logic — cancel the timer, drop the invite, remove the server invite-exception, and
  (on accept) join the channel + post the status line — lives here on the parent.
  """

  import Phoenix.Component, only: [assign: 2]
  import RetroHexChatWeb.ChatLive.Helpers

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Channels.Server

  @spec accept(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def accept(socket, channel) do
    pending = socket.assigns.pending_invites
    session = socket.assigns.session

    case find_invite(pending, channel) do
      nil ->
        error_event(socket, dgettext("chat", "This invitation has expired"))

      invite ->
        Process.cancel_timer(invite.timer_ref)
        remaining = Enum.reject(pending, &(&1.channel == channel))
        try_remove_invite_exception(channel, session.nickname)

        socket
        |> assign(pending_invites: remaining)
        |> push_status_message(
          dgettext("chat", "* Accepted invite to %{channel} from %{inviter}",
            channel: channel,
            inviter: invite.inviter
          ),
          :system
        )
        |> join_channel(channel, session)
    end
  end

  @spec ignore(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def ignore(socket, channel) do
    pending = socket.assigns.pending_invites
    session = socket.assigns.session

    case find_invite(pending, channel) do
      nil ->
        socket

      invite ->
        Process.cancel_timer(invite.timer_ref)
        remaining = Enum.reject(pending, &(&1.channel == channel))
        try_remove_invite_exception(channel, session.nickname)

        socket
        |> assign(pending_invites: remaining)
        |> push_status_message(
          dgettext("chat", "* Ignored invite to %{channel}", channel: channel),
          :system
        )
    end
  end

  # ── Private ────────────────────────────────────────────────

  defp find_invite(pending, channel) do
    Enum.find(pending, &(&1.channel == channel))
  end

  defp try_remove_invite_exception(channel, nickname) do
    Server.remove_invite_exception(channel, nickname, nickname)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end
end
