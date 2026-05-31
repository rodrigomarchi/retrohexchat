defmodule RetroHexChatWeb.ChatLive.UiActions.Bots do
  @moduledoc """
  Bot UI actions: open dialog, create bot, etc.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers, only: [error_event: 2]

  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChat.Bots.Queries

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :open_bot_dialog, _payload) do
    session = socket.assigns.session

    if admin?(session) do
      bots = Queries.list_bots()
      assign(socket, show_bot_dialog: true, bot_dialog_bots: bots)
    else
      error_event(
        socket,
        dgettext("chat", "Bot management is restricted to server administrators.")
      )
    end
  end

  defp admin?(session) do
    ServerRoles.admin?(session.nickname, session.identified) or
      ServerRoles.server_operator?(session.nickname, session.identified)
  end
end
