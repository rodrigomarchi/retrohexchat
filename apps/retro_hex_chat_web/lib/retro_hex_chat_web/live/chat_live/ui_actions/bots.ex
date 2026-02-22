defmodule RetroHexChatWeb.ChatLive.UiActions.Bots do
  @moduledoc """
  Bot UI actions: open dialog, create bot, etc.
  """

  import Phoenix.Component, only: [assign: 2]

  alias RetroHexChat.Bots.Queries

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :open_bot_dialog, _payload) do
    bots = Queries.list_bots()
    assign(socket, show_bot_dialog: true, bot_dialog_bots: bots)
  end
end
