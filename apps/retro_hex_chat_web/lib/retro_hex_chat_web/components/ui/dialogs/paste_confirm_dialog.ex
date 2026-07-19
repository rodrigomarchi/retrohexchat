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
      <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="cd-dialog-wrap">
        <.dialog_header
          id={@id}
          title={dgettext("dialogs", "Paste Confirmation")}
          on_close={@on_cancel}
        >
          <:icon><Icons.icon_dialog_paste class="w-4 h-4" /></:icon>
        </.dialog_header>

        <.dialog_body class="cd-dialog-body">
          <div class="cd-paste-stack">
            <div class="cd-message-row">
              <span class="cd-message-icon" aria-hidden="true">
                <Icons.icon_dialog_paste class="w-5 h-5" />
              </span>
              <div class="cd-message-copy">
                <p class="cd-message-text">
                  {dgettext("dialogs", "You are about to send %{count} of text.",
                    count: dngettext("dialogs", "%{count} line", "%{count} lines", @line_count)
                  )}
                </p>
                <p class="cd-message-note">
                  {dgettext("dialogs", "Send them as a paced batch to the active conversation.")}
                </p>
              </div>
            </div>

            <div
              :if={@flood_warning}
              class="cd-callout"
              data-testid="paste-flood-warning"
            >
              <Icons.icon_warning class="w-4 h-4 shrink-0" />
              <p>
                {dgettext(
                  "dialogs",
                  "Warning: This exceeds the flood protection limit. Messages may be throttled."
                )}
              </p>
            </div>

            <p class="cd-message-question">
              {dgettext("dialogs", "Are you sure you want to send all lines at once?")}
            </p>
          </div>
        </.dialog_body>

        <.dialog_footer class="cd-dialog-footer">
          <.button
            variant="default"
            phx-click={@on_send}
            disabled={@send_disabled}
            data-testid="paste-confirm-send"
            class="cd-dialog-action"
          >
            <:icon><Icons.icon_dialog_paste class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Send All")}
          </.button>
          <.button
            variant="outline"
            phx-click={@on_cancel || hide_modal(@id)}
            data-testid="paste-confirm-cancel"
            class="cd-dialog-action"
          >
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Cancel")}
          </.button>
        </.dialog_footer>
      </.dialog>
    </span>
    """
  end
end
