defmodule RetroHexChatWeb.Components.UI.KickDialog do
  @moduledoc """
  Kick notification dialog for the showcase design system.

  Composed from dialog + button primitives. Displays a notification when the
  current user has been kicked from a channel, with details about the channel,
  kicker, and reason.

  ## Usage

      <.kick_dialog
        id="kick-notify"
        show={true}
        kick_info={%{channel: "#lobby", kicker: "Admin", reason: "Flooding"}}
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders a kick notification dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :kick_info, :map,
    default: nil,
    doc: "Map with keys :channel, :kicker, :reason"

  attr :on_dismiss, :any, default: nil, doc: "JS command or event name to dismiss"

  @spec kick_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def kick_dialog(assigns) do
    ~H"""
    <span data-testid="kick-dialog">
      <.dialog id={@id} show={@show}>
        <.dialog_header id={@id} title={gettext("Kicked from Channel")}>
          <:icon><Icons.icon_dialog_kick class="w-[16px] h-[16px]" /></:icon>
        </.dialog_header>

        <.dialog_body>
          <p class="text-xs">
            <%= if @kick_info do %>
              {gettext("You were kicked from %{channel} by %{kicker} (%{reason}).",
                channel: @kick_info[:channel],
                kicker: @kick_info[:kicker],
                reason: @kick_info[:reason]
              )}
            <% else %>
              {gettext("You were kicked from the channel.")}
            <% end %>
          </p>
        </.dialog_body>

        <.dialog_footer>
          <.button
            variant="default"
            phx-click={@on_dismiss || hide_modal(@id)}
            data-testid="kick-dialog-ok"
          >
            <:icon><Icons.icon_btn_ok class="w-4 h-4" /></:icon>
            {gettext("OK")}
          </.button>
        </.dialog_footer>
      </.dialog>
    </span>
    """
  end
end
