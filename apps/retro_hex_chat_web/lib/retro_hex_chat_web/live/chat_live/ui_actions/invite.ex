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
    case send_invite(socket, target, channel) do
      {:ok, socket} -> socket
      {:error, socket, _message} -> socket
    end
  end

  def handle_ui_action(socket, :toggle_auto_join_on_invite, _payload) do
    session = socket.assigns.session
    new_session = Session.toggle_auto_join_on_invite(session)

    status =
      if new_session.auto_join_on_invite,
        do: dgettext("chat", "enabled"),
        else: dgettext("chat", "disabled")

    socket
    |> assign(session: new_session)
    |> system_event(dgettext("chat", "* Auto-join on invite: %{status}", status: status))
  end

  @spec send_invite(Phoenix.LiveView.Socket.t(), String.t(), String.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()} | {:error, Phoenix.LiveView.Socket.t(), String.t()}
  def send_invite(socket, target, channel) do
    nickname = socket.assigns.session.nickname

    with :ok <- validate_present(target, dgettext("chat", "* Missing invite target")),
         :ok <- validate_present(channel, dgettext("chat", "* Missing invite channel")),
         {:ok, state} <- get_channel_state(channel),
         :ok <- validate_operator(nickname, state),
         :ok <- validate_invite_only(channel, state),
         :ok <- validate_target_not_in_channel(target, state),
         :ok <- validate_target_online(target),
         :ok <- Server.add_invite_exception(channel, nickname, target) do
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "user:#{target}",
        {:channel_invite, %{channel: channel, inviter: nickname}}
      )

      {:ok,
       system_event(
         socket,
         dgettext("chat", "* Inviting %{target} to %{channel}", target: target, channel: channel)
       )}
    else
      {:error, msg} ->
        {:error, error_event(socket, msg), msg}
    end
  end

  # Private helpers

  defp validate_present(value, message) when is_binary(value) do
    if String.trim(value) == "", do: {:error, message}, else: :ok
  end

  defp validate_present(_value, message), do: {:error, message}

  defp get_channel_state(channel) do
    case Server.get_state(channel) do
      {:ok, state} -> {:ok, state}
      {:error, _reason} -> {:error, dgettext("chat", "* Channel not found")}
    end
  end

  defp validate_operator(nickname, state) do
    if nickname in state.operators or nickname in Map.get(state, :owners, []) do
      :ok
    else
      {:error, dgettext("chat", "* You are not a channel operator")}
    end
  end

  defp validate_invite_only(channel, state) do
    if state.modes_detail.invite_only do
      :ok
    else
      {:error,
       dgettext("chat", "* %{channel} is not invite-only — anyone can join", channel: channel)}
    end
  end

  defp validate_target_not_in_channel(target, state) do
    member_nicks = Enum.map(state.members, fn {nick, _role} -> nick end)

    if target in member_nicks do
      {:error, dgettext("chat", "* %{target} is already in the channel", target: target)}
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
          {:error, dgettext("chat", "* User '%{target}' not found", target: target)}
        end

      {:error, _} ->
        {:error, dgettext("chat", "* User '%{target}' not found", target: target)}
    end
  end
end
