defmodule RetroHexChatWeb.Components.NickChangeDialog do
  @moduledoc """
  Nick change confirmation dialog: warns that changing nickname starts a new session.
  If the target nick is registered with NickServ, a password field is shown.
  """
  use Phoenix.Component

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
          <div class="title-bar-text">Mudar Nickname</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="cancel_nick_change"></button>
          </div>
        </div>
        <div class="window-body nick-change-dialog__body">
          <p>
            Mudar para <strong>{@target_nick}</strong>? Isso iniciará uma nova sessão de chat.
          </p>
          <fieldset :if={@registered}>
            <legend>Autenticação NickServ</legend>
            <p>
              O nick <strong>{@target_nick}</strong> é registrado. Digite a senha para continuar:
            </p>
            <div class="nick-change-dialog__password-row">
              <input
                type="password"
                name="password"
                value={@password}
                phx-keyup="update_nick_change_password"
                phx-keydown="confirm_nick_change"
                phx-key="Enter"
                phx-value-password={@password}
                placeholder="Senha"
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
              phx-click="confirm_nick_change"
              phx-value-password={@password}
              data-testid="nick-change-confirm-btn"
            >
              Confirmar
            </button>
            <button phx-click="cancel_nick_change" data-testid="nick-change-cancel-btn">
              Cancelar
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
