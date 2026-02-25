defmodule RetroHexChatWeb.Components.AdminConsoleDialog do
  @moduledoc """
  Admin Console dialog: batch command execution for server administrators.
  Accepts multi-line input (one command per line) and executes them sequentially,
  displaying results inline.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :visible, :boolean, default: false
  attr :results, :list, default: []

  @spec admin_console_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_console_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      phx-window-keydown="close_admin_console"
      phx-key="Escape"
      data-testid="admin-console-dialog"
    >
      <div class="window admin-console-window">
        <div class="title-bar">
          <Icons.icon_dialog_admin_console class="title-bar-icon" />
          <div class="title-bar-text">Admin Console</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="close_admin_console"></button>
          </div>
        </div>
        <div class="window-body admin-console-body">
          <form phx-submit="execute_admin_console" class="admin-console-form">
            <fieldset class="admin-console-fieldset">
              <legend>Commands (one per line, # for comments)</legend>
              <textarea
                name="input"
                class="admin-console-textarea"
                placeholder="# Example:\n/chanserv register #main\n/chanserv set #main guard on\n/bot create MyBot"
                rows="12"
                spellcheck="false"
                data-testid="admin-console-input"
              ></textarea>
            </fieldset>

            <fieldset
              :if={@results != []}
              class="admin-console-fieldset admin-console-results-fieldset"
            >
              <legend>Results ({length(@results)} commands)</legend>
              <div class="admin-console-results" data-testid="admin-console-results">
                <div
                  :for={result <- @results}
                  class={"admin-console-result admin-console-result--#{result.status}"}
                  data-testid="admin-console-result-item"
                >
                  <span class="admin-console-result-icon">
                    {if result.status == :ok, do: "[OK]", else: "[ERR]"}
                  </span>
                  <span class="admin-console-result-cmd">{result.line}</span>
                  <span :if={result.message != ""} class="admin-console-result-msg">
                    — {result.message}
                  </span>
                </div>
              </div>
            </fieldset>

            <div class="admin-console-actions">
              <button type="submit" class="btn-icon" data-testid="admin-console-execute-btn">
                Execute
              </button>
              <button
                :if={@results != []}
                type="button"
                class="btn-icon"
                phx-click="clear_admin_console"
                data-testid="admin-console-clear-btn"
              >
                Clear
              </button>
              <button type="button" class="btn-icon" phx-click="close_admin_console">
                Close
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
