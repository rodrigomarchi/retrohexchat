defmodule RetroHexChatWeb.ChatLive.UiActions.Invite do
  @moduledoc """
  Invite UI actions: send invite, toggle auto-join on invite.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [system_event: 2, error_event: 2]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :send_invite, %{target: target, channel: channel}) do
    nickname = socket.assigns.session.nickname

    with {:ok, state} <- Server.get_state(channel),
         :ok <- validate_operator(nickname, state),
         :ok <- validate_invite_only(channel, state),
         :ok <- validate_target_not_in_channel(target, state),
         :ok <- validate_target_online(target) do
      Server.add_invite_exception(channel, nickname, target)

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "user:#{target}",
        {:channel_invite, %{channel: channel, inviter: nickname}}
      )

      system_event(
        socket,
        gettext("* Inviting %{target} to %{channel}", target: target, channel: channel)
      )
    else
      {:error, msg} ->
        error_event(socket, msg)
    end
  end

  def handle_ui_action(socket, :toggle_auto_join_on_invite, _payload) do
    session = socket.assigns.session
    new_session = Session.toggle_auto_join_on_invite(session)
    status = if new_session.auto_join_on_invite, do: gettext("enabled"), else: gettext("disabled")

    socket
    |> assign(session: new_session)
    |> system_event(gettext("* Auto-join on invite: %{status}", status: status))
  end

  # Private helpers

  defp validate_operator(nickname, state) do
    if nickname in state.operators or nickname in Map.get(state, :owners, []) do
      :ok
    else
      {:error, gettext("* You are not a channel operator")}
    end
  end

  defp validate_invite_only(channel, state) do
    if state.modes_detail.invite_only do
      :ok
    else
      {:error, gettext("* %{channel} is not invite-only — anyone can join", channel: channel)}
    end
  end

  defp validate_target_not_in_channel(target, state) do
    member_nicks = Enum.map(state.members, fn {nick, _role} -> nick end)

    if target in member_nicks do
      {:error, gettext("* %{target} is already in the channel", target: target)}
    else
      :ok
    end
  end

  defp validate_target_online(target) do
    case Server.get_state("#lobby") do
      {:ok, state} ->
        member_nicks = Enum.map(state.members, fn {nick, _role} -> nick end)

        if target in member_nicks do
          :ok
        else
          {:error, gettext("* User '%{target}' not found", target: target)}
        end

      {:error, _} ->
        {:error, gettext("* User '%{target}' not found", target: target)}
    end
  end
end
