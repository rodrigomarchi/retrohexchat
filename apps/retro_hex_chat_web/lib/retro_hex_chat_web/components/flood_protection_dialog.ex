defmodule RetroHexChatWeb.Components.FloodProtectionDialog do
  @moduledoc """
  Windows 98-styled dialog for configuring flood protection settings.
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :flood_protection, :map, required: true

  @spec flood_protection_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def flood_protection_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      data-testid="flood-protection-dialog"
    >
      <div class="window dialog-window--md">
        <div class="title-bar">
          <div class="title-bar-text">Flood Protection</div>
          <div class="title-bar-controls">
            <button
              aria-label="Close"
              phx-click="close_flood_protection_dialog"
            >
            </button>
          </div>
        </div>
        <div class="window-body dialog-body--p8 u-flex-col u-gap-8">
          <form id="flood-protection-form" phx-submit="flood_save_settings">
            <fieldset>
              <legend>Message Flood</legend>
              <div class="u-p-4 u-flex-col u-gap-4">
                <div class="form-row">
                  <label for="fp-threshold" class="u-min-w-120">Threshold:</label>
                  <input
                    type="number"
                    id="fp-threshold"
                    name="flood_threshold"
                    value={@flood_protection.flood_threshold}
                    min="1"
                    max="100"
                    class="u-w-60"
                  />
                  <span class="u-text-sm u-text-disabled">messages</span>
                </div>
                <div class="form-row">
                  <label for="fp-window" class="u-min-w-120">Time window:</label>
                  <input
                    type="number"
                    id="fp-window"
                    name="flood_window_seconds"
                    value={@flood_protection.flood_window_seconds}
                    min="1"
                    max="300"
                    class="u-w-60"
                  />
                  <span class="u-text-sm u-text-disabled">seconds</span>
                </div>
              </div>
            </fieldset>

            <fieldset class="u-mt-4">
              <legend>Anti-Spam (Duplicate Detection)</legend>
              <div class="u-p-4 u-flex-col u-gap-4">
                <div class="form-row">
                  <label for="fp-spam-threshold" class="u-min-w-120">Duplicate limit:</label>
                  <input
                    type="number"
                    id="fp-spam-threshold"
                    name="spam_threshold"
                    value={@flood_protection.spam_threshold}
                    min="1"
                    max="50"
                    class="u-w-60"
                  />
                  <span class="u-text-sm u-text-disabled">identical msgs</span>
                </div>
                <div class="form-row">
                  <label for="fp-spam-window" class="u-min-w-120">Time window:</label>
                  <input
                    type="number"
                    id="fp-spam-window"
                    name="spam_window_seconds"
                    value={@flood_protection.spam_window_seconds}
                    min="1"
                    max="120"
                    class="u-w-60"
                  />
                  <span class="u-text-sm u-text-disabled">seconds</span>
                </div>
              </div>
            </fieldset>

            <fieldset class="u-mt-4">
              <legend>Auto-Ignore</legend>
              <div class="u-p-4 form-row">
                <label for="fp-ignore-duration" class="u-min-w-120">Duration:</label>
                <input
                  type="number"
                  id="fp-ignore-duration"
                  name="auto_ignore_duration_seconds"
                  value={@flood_protection.auto_ignore_duration_seconds}
                  min="1"
                  max="86400"
                  class="u-w-80"
                />
                <span class="u-text-sm u-text-disabled">seconds</span>
              </div>
            </fieldset>

            <fieldset class="u-mt-4">
              <legend>CTCP Reply Limit</legend>
              <div class="u-p-4 u-flex-col u-gap-4">
                <div class="form-row">
                  <label for="fp-ctcp-limit" class="u-min-w-120">Reply limit:</label>
                  <input
                    type="number"
                    id="fp-ctcp-limit"
                    name="ctcp_reply_limit"
                    value={@flood_protection.ctcp_reply_limit}
                    min="1"
                    max="20"
                    class="u-w-60"
                  />
                  <span class="u-text-sm u-text-disabled">replies</span>
                </div>
                <div class="form-row">
                  <label for="fp-ctcp-window" class="u-min-w-120">Time window:</label>
                  <input
                    type="number"
                    id="fp-ctcp-window"
                    name="ctcp_reply_window_seconds"
                    value={@flood_protection.ctcp_reply_window_seconds}
                    min="1"
                    max="120"
                    class="u-w-60"
                  />
                  <span class="u-text-sm u-text-disabled">seconds</span>
                </div>
              </div>
            </fieldset>

            <div class="dialog-buttons u-mt-8">
              <button type="submit">Save</button>
              <button type="button" phx-click="flood_reset_defaults">Reset Defaults</button>
              <button type="button" phx-click="close_flood_protection_dialog">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
