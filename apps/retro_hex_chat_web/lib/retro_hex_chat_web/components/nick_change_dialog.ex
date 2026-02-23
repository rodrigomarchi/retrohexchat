defmodule RetroHexChatWeb.Components.NickChangeDialog do
  @moduledoc """
  Nick change confirmation dialog: warns that changing nickname starts a new session.
  If the target nick is registered with NickServ, a password field is shown.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :visible, :boolean, default: false
  attr :target_nick, :string, default: ""
  attr :registered, :boolean, default: false
  attr :password, :string, default: ""
  attr :password_error, :string, default: nil

  @spec nick_change_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def nick_change_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      phx-window-keydown="cancel_nick_change"
      phx-key="Escape"
      data-testid="nick-change-dialog"
    >
      <div class="window nick-change-dialog">
        <div class="title-bar">
          <Icons.icon_dialog_nick class="title-bar-icon" />
          <div class="title-bar-text">Change Nickname</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="cancel_nick_change"></button>
          </div>
        </div>
        <div class="window-body nick-change-dialog__body">
          <p>
            Change to <strong>{@target_nick}</strong>? This will start a new chat session.
          </p>
          <fieldset :if={@registered}>
            <legend>NickServ Authentication</legend>
            <p>
              The nick <strong>{@target_nick}</strong> is registered. Enter the password to continue:
            </p>
            <div class="nick-change-dialog__password-row">
              <input
                type="text"
                class="input-masked"
                name="password"
                value={@password}
                phx-keyup="update_nick_change_password"
                phx-keydown="confirm_nick_change"
                phx-key="Enter"
                phx-value-password={@password}
                placeholder="Password"
                id="nick-change-password-input"
                phx-hook="AutoFocusHook"
                data-testid="nick-change-password"
              />
            </div>
            <p :if={@password_error} class="nick-change-dialog__error" data-testid="nick-change-error">
              {@password_error}
            </p>
          </fieldset>
          <div class="nick-change-dialog__actions">
            <button
              class="btn-icon"
              phx-click="confirm_nick_change"
              phx-value-password={@password}
              data-testid="nick-change-confirm-btn"
            >
              <Icons.icon_btn_ok class="btn-icon__svg" /> Confirm
            </button>
            <button
              class="btn-icon"
              phx-click="cancel_nick_change"
              data-testid="nick-change-cancel-btn"
            >
              <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
