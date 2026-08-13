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

  attr :password, :string, default: "", doc: "Current password value (tracked via keyup)"
  attr :password_error, :string, default: nil, doc: "Error message for invalid password"
  attr :on_confirm, :any, default: nil, doc: "JS command or event name for confirm"
  attr :on_cancel, :any, default: nil, doc: "JS command or event name for cancel"
  attr :on_password_change, :any, default: nil, doc: "Password keyup callback"

  @spec nick_change_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def nick_change_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="nc-dialog-wrap">
      <.dialog_header id={@id} title={dgettext("dialogs", "Change Nickname")} on_close={@on_cancel}>
        <:icon><Icons.icon_dialog_nick class="w-4 h-4" /></:icon>
      </.dialog_header>

      <%!-- Both the password and the target travel with the submit, so what
      reaches the server is what is on screen. Reading them from assigns meant
      sending whatever the last keyup had time to store — the previous attempt's
      password, for anyone who retypes and confirms without pausing. --%>
      <form id={"#{@id}-form"} phx-submit={@on_confirm}>
        <input type="hidden" name="target" value={@target_nick} />
        <input type="hidden" name="registered" value={to_string(@registered)} />

        <.dialog_body class="nc-dialog-body">
          <div class="nc-dialog-content" data-testid="nick-change-dialog">
            <div class="nc-target-card">
              <span class="nc-target-icon" aria-hidden="true">
                <Icons.icon_dialog_nick class="w-4 h-4" />
              </span>
              <div class="nc-target-copy">
                <p class="nc-field-label">{dgettext("dialogs", "Changing nickname to")}</p>
                <p class="nc-target-value">{@target_nick}</p>
              </div>
            </div>

            <div :if={@registered} class="nc-notice">
              {dgettext(
                "dialogs",
                "This nickname is registered. Please enter the NickServ password to identify."
              )}
            </div>

            <div :if={@registered} class="nc-field-group">
              <label for={"#{@id}-password"} class="nc-field-label">
                {dgettext("dialogs", "NickServ password")}
              </label>
              <.input
                id={"#{@id}-password"}
                name="password"
                type="password"
                value={@password}
                placeholder={dgettext("dialogs", "Enter password")}
                class="nc-password-input"
                phx-keyup={@on_password_change}
                data-testid="nick-change-password"
              />

              <p :if={@password_error} class="nc-error" data-testid="nick-change-error">
                {@password_error}
              </p>
            </div>
          </div>
        </.dialog_body>

        <.dialog_footer class="nc-dialog-footer">
          <.button
            type="submit"
            variant="default"
            data-testid="nick-change-confirm"
            class="nc-action-button"
          >
            <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Confirm")}
          </.button>
          <.button
            variant="outline"
            phx-click={@on_cancel || hide_modal(@id)}
            data-testid="nick-change-cancel"
            class="nc-action-button"
          >
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Cancel")}
          </.button>
        </.dialog_footer>
      </form>
    </.dialog>
    """
  end
end
