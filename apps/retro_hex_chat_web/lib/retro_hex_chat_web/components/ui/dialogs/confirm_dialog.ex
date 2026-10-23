defmodule RetroHexChatWeb.Components.UI.ConfirmDialog do
  @moduledoc """
  The one confirmation every "are you sure?" in the app is drawn with.

  A question, what answering yes will do, and two buttons. Deleting a message,
  disconnecting, sending a pasted block, following a link out, ending a P2P
  session or a group call: each is this dialog with its own words, icons and
  tone, so all of them close the same way — the X, Escape and Cancel are one
  answer, `on_cancel` — and none can drift from the others in how it looks.

  ## Usage

      <.confirm_dialog
        id="delete-confirm"
        show={true}
        title="Delete Message"
        message="Are you sure you want to delete this message?"
        icon={:icon_dialog_delete}
        confirm_label="Delete"
        confirm_icon={:icon_dialog_delete}
        variant="destructive"
        on_confirm="delete_message"
        on_cancel="cancel_delete"
      >
        <:note>This action cannot be undone.</:note>
      </.confirm_dialog>
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.DialogMessage
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders a confirmation dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :scope, :atom,
    default: :viewport,
    values: [:viewport, :window],
    doc: "`:window` when the host renders it inside a desktop window of its own"

  attr :title, :string, required: true
  attr :message, :string, required: true
  attr :message_testid, :string, default: nil

  attr :icon, :atom,
    default: :icon_warning,
    doc: "an `RetroHexChatWeb.Icons` function, for the title"

  attr :glyph, :atom, default: nil, doc: "the icon beside the question; the title's when nil"
  attr :tone, :atom, default: :normal, doc: "`DialogMessage` tone: how bad the answer is"

  attr :impacts, :list,
    default: [],
    doc: "what yes does, one line each: `%{icon: atom, label: String.t()}`"

  attr :variant, :string, default: "default", values: ~w(default destructive)
  attr :confirm_label, :string, default: nil
  attr :confirm_icon, :atom, default: :icon_checkmark
  attr :confirm_disabled, :boolean, default: false
  attr :confirm_href, :string, default: nil, doc: "makes yes a link opening in a new tab"
  attr :cancel_label, :string, default: nil
  attr :on_confirm, :any, default: nil, doc: "JS command or event name for yes"

  attr :on_cancel, :any,
    default: nil,
    doc: "JS command or event name for the X, Escape and Cancel (default: hide the modal)"

  attr :testid, :string, default: nil, doc: "the wrapper's test id; the dialog id when nil"
  attr :confirm_testid, :string, default: nil
  attr :cancel_testid, :string, default: nil

  slot :note,
    doc: "What happens if the reader confirms. A question without this makes them guess."

  slot :inner_block, doc: "Anything the dialog says after its question, such as a warning"

  @spec confirm_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def confirm_dialog(assigns) do
    testid = assigns.testid || assigns.id

    assigns =
      assigns
      |> assign(:testid, testid)
      |> assign(:confirm_testid, assigns.confirm_testid || "#{testid}-confirm")
      |> assign(:cancel_testid, assigns.cancel_testid || "#{testid}-cancel")
      |> assign(:glyph, assigns.glyph || assigns.icon)
      |> assign(:confirm_label, assigns.confirm_label || dgettext("dialogs", "OK"))
      |> assign(:cancel_label, assigns.cancel_label || dgettext("dialogs", "Cancel"))

    ~H"""
    <span data-testid={@testid}>
      <.dialog id={@id} show={@show} scope={@scope} on_cancel={@on_cancel} class="cd-dialog-wrap">
        <.dialog_header id={@id} title={@title} on_close={@on_cancel}>
          <:icon><.icon name={@icon} class="h-[16px] w-[16px]" /></:icon>
        </.dialog_header>

        <.dialog_body class="cd-dialog-body">
          <.dialog_message tone={@tone}>
            <:glyph><.icon name={@glyph} class="h-5 w-5" /></:glyph>
            <span data-testid={@message_testid}>{@message}</span>
            <:note :if={@note != [] or @impacts != []}>
              <div :if={@impacts != []} class="grid gap-1">
                <div :for={impact <- @impacts} class="flex min-w-0 items-center gap-1">
                  <.icon name={impact.icon} class="h-3.5 w-3.5 shrink-0" />
                  <span class="truncate">{impact.label}</span>
                </div>
              </div>
              {render_slot(@note)}
            </:note>
          </.dialog_message>
          {render_slot(@inner_block)}
        </.dialog_body>

        <.dialog_footer class="cd-dialog-footer">
          <.button
            variant={@variant}
            href={@confirm_href}
            target={@confirm_href && "_blank"}
            rel={@confirm_href && "noopener"}
            phx-click={@on_confirm}
            disabled={@confirm_disabled}
            data-testid={@confirm_testid}
            class="cd-dialog-action"
          >
            <:icon><.icon name={@confirm_icon} class="h-4 w-4" /></:icon>
            {@confirm_label}
          </.button>
          <.button
            variant="outline"
            phx-click={@on_cancel || hide_modal(@id)}
            data-testid={@cancel_testid}
            class="cd-dialog-action"
          >
            <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
            {@cancel_label}
          </.button>
        </.dialog_footer>
      </.dialog>
    </span>
    """
  end

  attr :name, :atom, required: true
  attr :class, :string, default: nil

  defp icon(assigns) do
    ~H"""
    {apply(Icons, @name, [%{class: @class}])}
    """
  end
end
