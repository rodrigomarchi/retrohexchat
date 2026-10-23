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

  import RetroHexChatWeb.Components.UI.ConfirmDialog

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
    <.confirm_dialog
      id={@id}
      show={@show}
      testid="paste-confirm-dialog"
      confirm_testid="paste-confirm-send"
      cancel_testid="paste-confirm-cancel"
      title={dgettext("dialogs", "Paste Confirmation")}
      message={
        dgettext("dialogs", "You are about to send %{count} of text.",
          count: dngettext("dialogs", "%{count} line", "%{count} lines", @line_count)
        )
      }
      icon={:icon_dialog_paste}
      confirm_label={dgettext("dialogs", "Send All")}
      confirm_icon={:icon_dialog_paste}
      confirm_disabled={@send_disabled}
      on_confirm={@on_send}
      on_cancel={@on_cancel}
    >
      <:note>{dgettext("dialogs", "Send them as a paced batch to the active conversation.")}</:note>

      <div class="cd-paste-stack">
        <div :if={@flood_warning} class="cd-callout" data-testid="paste-flood-warning">
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
    </.confirm_dialog>
    """
  end
end
