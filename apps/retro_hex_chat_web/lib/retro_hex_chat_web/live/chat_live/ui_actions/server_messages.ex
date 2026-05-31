defmodule RetroHexChatWeb.ChatLive.UiActions.ServerMessages do
  @moduledoc """
  UI actions for server messages: MOTD, welcome messages, user modes.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [system_event: 2, push_status_message: 3]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :show_motd, %{content: content}) do
    push_status_message(socket, content, :motd)
  end

  def handle_ui_action(socket, :set_welcome, %{channel: channel, message: message}) do
    nickname = socket.assigns.session.nickname

    case Server.set_welcome(channel, message, nickname) do
      :ok ->
        system_event(
          socket,
          dgettext("chat", "Welcome message for %{channel} has been set.", channel: channel)
        )

      {:error, msg} ->
        system_event(socket, dgettext("chat", "Error: %{message}", message: msg))
    end
  end

  def handle_ui_action(socket, :clear_welcome, %{channel: channel}) do
    nickname = socket.assigns.session.nickname

    case Server.clear_welcome(channel, nickname) do
      :ok ->
        system_event(
          socket,
          dgettext("chat", "Welcome message for %{channel} has been cleared.", channel: channel)
        )

      {:error, msg} ->
        system_event(socket, dgettext("chat", "Error: %{message}", message: msg))
    end
  end

  def handle_ui_action(socket, :set_user_mode, %{mode_string: mode_string}) do
    session = socket.assigns.session

    case parse_and_apply_mode(session, mode_string) do
      {:ok, new_session, confirmation} ->
        socket
        |> assign(session: new_session)
        |> push_status_message(confirmation, :system)

      {:error, msg} ->
        push_status_message(socket, msg, :error)
    end
  end

  defp parse_and_apply_mode(session, "+" <> flag) do
    mode = flag_to_mode(flag)

    if mode do
      new_session = Session.set_mode(session, mode)
      {:ok, new_session, dgettext("chat", "User mode +%{flag} enabled.", flag: flag)}
    else
      {:error, dgettext("chat", "Unknown user mode: %{flag}", flag: flag)}
    end
  end

  defp parse_and_apply_mode(session, "-" <> flag) do
    mode = flag_to_mode(flag)

    if mode do
      new_session = Session.unset_mode(session, mode)
      {:ok, new_session, dgettext("chat", "User mode -%{flag} disabled.", flag: flag)}
    else
      {:error, dgettext("chat", "Unknown user mode: %{flag}", flag: flag)}
    end
  end

  defp parse_and_apply_mode(_session, _), do: {:error, dgettext("chat", "Invalid mode string.")}

  defp flag_to_mode("w"), do: :wallops
  defp flag_to_mode(_), do: nil
end
