defmodule RetroHexChatWeb.Components.CtcpSettingsDialog do
  @moduledoc """
  Windows 98-styled CTCP settings dialog for customizing CTCP responses.
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :ctcp_settings, :map, required: true

  @spec ctcp_settings_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def ctcp_settings_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.3);"
    >
      <div class="window" style="width: 380px; min-height: 250px;">
        <div class="title-bar">
          <div class="title-bar-text">CTCP Settings</div>
          <div class="title-bar-controls">
            <button
              aria-label="Close"
              phx-click="close_ctcp_settings_dialog"
            >
            </button>
          </div>
        </div>
        <div
          class="window-body"
          style="padding: 8px; display: flex; flex-direction: column; gap: 8px;"
        >
          <fieldset>
            <legend>General</legend>
            <div style="padding: 4px;">
              <label style="display: flex; align-items: center; gap: 4px; cursor: pointer;">
                <input
                  type="checkbox"
                  id="ctcp-enabled"
                  checked={@ctcp_settings.enabled}
                  form="ctcp-settings-form"
                  name="enabled"
                  value="true"
                /> Enable CTCP responses
              </label>
              <p style="margin: 4px 0 0 20px; font-size: 11px; color: #999;">
                When disabled, other users will see a timeout when sending you CTCP requests.
              </p>
            </div>
          </fieldset>

          <form id="ctcp-settings-form" phx-submit="ctcp_save_settings">
            <input type="hidden" name="enabled" value={to_string(@ctcp_settings.enabled)} />

            <fieldset>
              <legend>VERSION Reply</legend>
              <div style="padding: 4px;">
                <label for="ctcp-version">Version string:</label>
                <input
                  type="text"
                  id="ctcp-version"
                  name="version_string"
                  value={@ctcp_settings.version_string}
                  maxlength="200"
                  style="width: 100%; box-sizing: border-box; margin-top: 2px;"
                />
              </div>
            </fieldset>

            <fieldset style="margin-top: 4px;">
              <legend>FINGER Reply</legend>
              <div style="padding: 4px;">
                <label for="ctcp-finger">Custom text (leave empty for auto-generated):</label>
                <input
                  type="text"
                  id="ctcp-finger"
                  name="finger_text"
                  value={@ctcp_settings.finger_text || ""}
                  maxlength="200"
                  style="width: 100%; box-sizing: border-box; margin-top: 2px;"
                  placeholder="e.g. Alice - Elixir developer from Brazil"
                />
              </div>
            </fieldset>

            <div style="margin-top: 8px; display: flex; justify-content: flex-end; gap: 4px;">
              <button type="submit">Save</button>
              <button type="button" phx-click="close_ctcp_settings_dialog">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
