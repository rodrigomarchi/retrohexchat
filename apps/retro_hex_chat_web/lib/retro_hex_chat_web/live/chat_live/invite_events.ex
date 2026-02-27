defmodule RetroHexChatWeb.ChatLive.InviteEvents do
  @moduledoc """
  Handle events for channel invite accept/ignore dialogs.

  Covers: invite_accept, invite_ignore.

  Attached as `attach_hook(:invite_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import RetroHexChatWeb.ChatLive.Helpers

  alias RetroHexChat.Channels.Server

  def handle_event("invite_accept", %{"channel" => channel}, socket) do
    pending = socket.assigns.pending_invites
    session = socket.assigns.session

    case find_invite(pending, channel) do
      nil ->
        {:halt, error_event(socket, "This invitation has expired")}

      invite ->
        Process.cancel_timer(invite.timer_ref)
        remaining = Enum.reject(pending, &(&1.channel == channel))
        try_remove_invite_exception(channel, session.nickname)

        socket =
          socket
          |> assign(pending_invites: remaining)
          |> push_status_message(
            "* Accepted invite to #{channel} from #{invite.inviter}",
            :system
          )
          |> join_channel(channel, session)

        {:halt, socket}
    end
  end

  def handle_event("invite_ignore", %{"channel" => channel}, socket) do
    pending = socket.assigns.pending_invites
    session = socket.assigns.session

    case find_invite(pending, channel) do
      nil ->
        {:halt, assign(socket, pending_invites: pending)}

      invite ->
        Process.cancel_timer(invite.timer_ref)
        remaining = Enum.reject(pending, &(&1.channel == channel))
        try_remove_invite_exception(channel, session.nickname)

        socket =
          socket
          |> assign(pending_invites: remaining)
          |> push_status_message("* Ignored invite to #{channel}", :system)

        {:halt, socket}
    end
  end

  # ── Catch-all ──────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

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
