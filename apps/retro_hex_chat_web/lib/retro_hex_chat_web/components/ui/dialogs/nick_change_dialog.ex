defmodule RetroHexChatWeb.Components.UI.NickChangeDialog do
  @moduledoc """
  Nick change dialog component for the showcase design system.

  Composed from dialog + button + input primitives.
  Handles nick changes with optional password for registered nicknames.

  ## Usage

      <.nick_change_dialog
        id="nick-change"
        show={true}
        target_nick="alice"
        registered={true}
        on_confirm="confirm_nick_change"
        on_cancel="cancel_nick_change"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @doc "Renders the nick change confirmation dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :target_nick, :string, default: "", doc: "The nickname being changed to"

  attr :registered, :boolean,
    default: false,
    doc: "Whether the target nick is registered — shows password field when true"

  attr :password_error, :string, default: nil, doc: "Error message for invalid password"
  attr :on_confirm, :any, default: nil, doc: "JS command or event name for confirm"
  attr :on_cancel, :any, default: nil, doc: "JS command or event name for cancel"

  @spec nick_change_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def nick_change_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header id={@id} title="Change Nickname">
        <:icon><Icons.icon_dialog_nick class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
        <div class="space-y-retro-8" data-testid="nick-change-dialog">
          <%!-- Target nick info --%>
          <p class="text-xs">
            Changing nickname to: <span class="font-bold">{@target_nick}</span>
          </p>

          <%!-- Registered nick notice --%>
          <div :if={@registered} class="text-xs text-muted-foreground">
            This nickname is registered. Please enter the NickServ password to identify.
          </div>

          <%!-- Password field — only shown for registered nicks --%>
          <div :if={@registered} class="space-y-retro-2">
            <label for={"#{@id}-password"} class="text-xs font-bold">
              NickServ password:
            </label>
            <.input
              id={"#{@id}-password"}
              name="nickserv_password"
              type="password"
              placeholder="Enter password"
              class="text-xs h-7"
              data-testid="nick-change-password"
            />

            <%!-- Password error --%>
            <p :if={@password_error} class="text-xs text-error" data-testid="nick-change-error">
              {@password_error}
            </p>
          </div>
        </div>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default" phx-click={@on_confirm} data-testid="nick-change-confirm">
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          Confirm
        </.button>
        <.button
          variant="outline"
          phx-click={@on_cancel || hide_modal(@id)}
          data-testid="nick-change-cancel"
        >
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          Cancel
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end
end
