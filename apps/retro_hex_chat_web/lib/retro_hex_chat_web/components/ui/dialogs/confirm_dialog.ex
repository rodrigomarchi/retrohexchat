defmodule RetroHexChatWeb.Components.UI.ConfirmDialog do
  @moduledoc """
  Confirm dialog component for the showcase design system.

  Composed from dialog + button primitives.
  Reusable confirmation dialog with warning icon, message, action + cancel buttons.

  ## Usage

      <.confirm_dialog
        id="delete-confirm"
        title="Delete Channel"
        message="Are you sure you want to delete #lobby?"
        confirm_label="Delete"
        variant="destructive"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders a reusable confirmation dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :title, :string, default: nil
  attr :message, :string, required: true
  attr :confirm_label, :string, default: nil
  attr :cancel_label, :string, default: nil
  attr :variant, :string, default: "default", values: ~w(default destructive)
  attr :on_confirm, :any, default: nil, doc: "JS command or event name for confirm"

  attr :on_cancel, :any,
    default: nil,
    doc: "JS command or event name for cancel (default: hide modal)"

  attr :class, :string, default: nil
  slot :icon, doc: "Optional custom icon (default: warning)"

  @spec confirm_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def confirm_dialog(assigns) do
    assigns =
      assigns
      |> assign(:resolved_title, assigns.title || gettext("Confirm"))
      |> assign(:resolved_confirm_label, assigns.confirm_label || gettext("OK"))
      |> assign(:resolved_cancel_label, assigns.cancel_label || gettext("Cancel"))

    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header id={@id} title={@resolved_title}>
        <:icon>
          <%= if @icon != [] do %>
            {render_slot(@icon)}
          <% else %>
            <Icons.icon_warning class="w-8 h-8" />
          <% end %>
        </:icon>
      </.dialog_header>

      <.dialog_body class={@class}>
        <p class="text-xs">{@message}</p>
      </.dialog_body>

      <.dialog_footer>
        <.button variant={@variant} phx-click={@on_confirm} data-testid="confirm-dialog-confirm">
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          {@resolved_confirm_label}
        </.button>
        <.button
          variant="outline"
          phx-click={@on_cancel || hide_modal(@id)}
          data-testid="confirm-dialog-cancel"
        >
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          {@resolved_cancel_label}
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end
end
