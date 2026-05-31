defmodule RetroHexChatWeb.Components.UI.PasteConfirmDialog do
  @moduledoc """
  Multi-line paste confirmation dialog component for the showcase design system.

  Composed from dialog + button primitives.
  Warns the user before sending multiple lines of text, with an optional
  flood protection warning.

  ## Usage

      <.paste_confirm_dialog
        id="paste-confirm"
        show={true}
        line_count={12}
        flood_warning={true}
        on_send="send_paste"
        on_cancel="cancel_paste"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders a paste confirmation dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :line_count, :integer, default: 0
  attr :flood_warning, :boolean, default: false
  attr :send_disabled, :boolean, default: false
  attr :on_send, :any, default: nil, doc: "JS command or event name for sending"
  attr :on_cancel, :any, default: nil, doc: "JS command or event name for cancelling"

  @spec paste_confirm_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def paste_confirm_dialog(assigns) do
    ~H"""
    <span data-testid="paste-confirm-dialog">
      <.dialog id={@id} show={@show}>
        <.dialog_header id={@id} title={gettext("Paste Confirmation")}>
          <:icon><Icons.icon_dialog_paste class="w-4 h-4" /></:icon>
        </.dialog_header>

        <.dialog_body>
          <div class="space-y-retro-8">
            <p class="text-xs">
              {gettext("You are about to send %{count} of text.",
                count: ngettext("%{count} line", "%{count} lines", @line_count)
              )}
            </p>

            <div
              :if={@flood_warning}
              class="shadow-retro-field bg-white p-retro-8 flex items-start gap-retro-4"
              data-testid="paste-flood-warning"
            >
              <Icons.icon_warning class="w-4 h-4 shrink-0 mt-[1px]" />
              <p class="text-xs">
                {gettext(
                  "Warning: This exceeds the flood protection limit. Messages may be throttled."
                )}
              </p>
            </div>

            <p class="text-xs text-muted-foreground">
              {gettext("Are you sure you want to send all lines at once?")}
            </p>
          </div>
        </.dialog_body>

        <.dialog_footer>
          <.button
            variant="default"
            phx-click={@on_send}
            disabled={@send_disabled}
            data-testid="paste-confirm-send"
          >
            <:icon><Icons.icon_dialog_paste class="w-4 h-4" /></:icon>
            {gettext("Send All")}
          </.button>
          <.button
            variant="outline"
            phx-click={@on_cancel || hide_modal(@id)}
            data-testid="paste-confirm-cancel"
          >
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {gettext("Cancel")}
          </.button>
        </.dialog_footer>
      </.dialog>
    </span>
    """
  end
end
