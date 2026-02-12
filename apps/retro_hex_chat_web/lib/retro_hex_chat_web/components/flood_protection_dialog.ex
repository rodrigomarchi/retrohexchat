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
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.3);"
    >
      <div class="window" style="width: 400px; min-height: 300px;">
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
        <div
          class="window-body"
          style="padding: 8px; display: flex; flex-direction: column; gap: 8px;"
        >
          <form id="flood-protection-form" phx-submit="flood_save_settings">
            <fieldset>
              <legend>Message Flood</legend>
              <div style="padding: 4px; display: flex; flex-direction: column; gap: 4px;">
                <div style="display: flex; align-items: center; gap: 4px;">
                  <label for="fp-threshold" style="min-width: 120px;">Threshold:</label>
                  <input
                    type="number"
                    id="fp-threshold"
                    name="flood_threshold"
                    value={@flood_protection.flood_threshold}
                    min="1"
                    max="100"
                    style="width: 60px;"
                  />
                  <span style="font-size: 11px; color: #999;">messages</span>
                </div>
                <div style="display: flex; align-items: center; gap: 4px;">
                  <label for="fp-window" style="min-width: 120px;">Time window:</label>
                  <input
                    type="number"
                    id="fp-window"
                    name="flood_window_seconds"
                    value={@flood_protection.flood_window_seconds}
                    min="1"
                    max="300"
                    style="width: 60px;"
                  />
                  <span style="font-size: 11px; color: #999;">seconds</span>
                </div>
              </div>
            </fieldset>

            <fieldset style="margin-top: 4px;">
              <legend>Anti-Spam (Duplicate Detection)</legend>
              <div style="padding: 4px; display: flex; flex-direction: column; gap: 4px;">
                <div style="display: flex; align-items: center; gap: 4px;">
                  <label for="fp-spam-threshold" style="min-width: 120px;">Duplicate limit:</label>
                  <input
                    type="number"
                    id="fp-spam-threshold"
                    name="spam_threshold"
                    value={@flood_protection.spam_threshold}
                    min="1"
                    max="50"
                    style="width: 60px;"
                  />
                  <span style="font-size: 11px; color: #999;">identical msgs</span>
                </div>
                <div style="display: flex; align-items: center; gap: 4px;">
                  <label for="fp-spam-window" style="min-width: 120px;">Time window:</label>
                  <input
                    type="number"
                    id="fp-spam-window"
                    name="spam_window_seconds"
                    value={@flood_protection.spam_window_seconds}
                    min="1"
                    max="120"
                    style="width: 60px;"
                  />
                  <span style="font-size: 11px; color: #999;">seconds</span>
                </div>
              </div>
            </fieldset>

            <fieldset style="margin-top: 4px;">
              <legend>Auto-Ignore</legend>
              <div style="padding: 4px; display: flex; align-items: center; gap: 4px;">
                <label for="fp-ignore-duration" style="min-width: 120px;">Duration:</label>
                <input
                  type="number"
                  id="fp-ignore-duration"
                  name="auto_ignore_duration_seconds"
                  value={@flood_protection.auto_ignore_duration_seconds}
                  min="1"
                  max="86400"
                  style="width: 80px;"
                />
                <span style="font-size: 11px; color: #999;">seconds</span>
              </div>
            </fieldset>

            <fieldset style="margin-top: 4px;">
              <legend>CTCP Reply Limit</legend>
              <div style="padding: 4px; display: flex; flex-direction: column; gap: 4px;">
                <div style="display: flex; align-items: center; gap: 4px;">
                  <label for="fp-ctcp-limit" style="min-width: 120px;">Reply limit:</label>
                  <input
                    type="number"
                    id="fp-ctcp-limit"
                    name="ctcp_reply_limit"
                    value={@flood_protection.ctcp_reply_limit}
                    min="1"
                    max="20"
                    style="width: 60px;"
                  />
                  <span style="font-size: 11px; color: #999;">replies</span>
                </div>
                <div style="display: flex; align-items: center; gap: 4px;">
                  <label for="fp-ctcp-window" style="min-width: 120px;">Time window:</label>
                  <input
                    type="number"
                    id="fp-ctcp-window"
                    name="ctcp_reply_window_seconds"
                    value={@flood_protection.ctcp_reply_window_seconds}
                    min="1"
                    max="120"
                    style="width: 60px;"
                  />
                  <span style="font-size: 11px; color: #999;">seconds</span>
                </div>
              </div>
            </fieldset>

            <div style="margin-top: 8px; display: flex; justify-content: flex-end; gap: 4px;">
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
