defmodule RetroHexChatWeb.Components.CtcpSettingsDialog do
  @moduledoc """
  Retro-styled CTCP settings dialog for customizing CTCP responses.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :visible, :boolean, default: false
  attr :ctcp_settings, :map, required: true

  @spec ctcp_settings_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def ctcp_settings_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
    >
      <div class="window dialog-window--md">
        <div class="title-bar">
          <Icons.icon_dialog_ctcp class="title-bar-icon" />
          <div class="title-bar-text">CTCP Settings</div>
          <div class="title-bar-controls">
            <button
              aria-label="Close"
              phx-click="close_ctcp_settings_dialog"
            >
            </button>
          </div>
        </div>
        <div class="window-body dialog-body--p8 u-flex-col u-gap-8">
          <fieldset>
            <legend>General</legend>
            <div class="u-p-4">
              <label class="form-row u-cursor-pointer">
                <input
                  type="checkbox"
                  id="ctcp-enabled"
                  checked={@ctcp_settings.enabled}
                  form="ctcp-settings-form"
                  name="enabled"
                  value="true"
                /> Enable CTCP responses
              </label>
              <p class="form-hint ctcp-hint">
                When disabled, other users will see a timeout when sending you CTCP requests.
              </p>
            </div>
          </fieldset>

          <form id="ctcp-settings-form" phx-submit="ctcp_save_settings">
            <input type="hidden" name="enabled" value={to_string(@ctcp_settings.enabled)} />

            <fieldset>
              <legend>VERSION Reply</legend>
              <div class="u-p-4">
                <label for="ctcp-version">Version string:</label>
                <input
                  type="text"
                  id="ctcp-version"
                  name="version_string"
                  value={@ctcp_settings.version_string}
                  maxlength="200"
                  class="u-w-full u-mt-2"
                />
              </div>
            </fieldset>

            <fieldset class="u-mt-4">
              <legend>FINGER Reply</legend>
              <div class="u-p-4">
                <label for="ctcp-finger">Custom text (leave empty for auto-generated):</label>
                <input
                  type="text"
                  id="ctcp-finger"
                  name="finger_text"
                  value={@ctcp_settings.finger_text || ""}
                  maxlength="200"
                  class="u-w-full u-mt-2"
                  placeholder="e.g. Alice - Elixir developer from Brazil"
                />
              </div>
            </fieldset>

            <div class="dialog-buttons u-mt-8">
              <button type="submit" class="btn-icon">
                <Icons.icon_btn_save class="btn-icon__svg" /> Save
              </button>
              <button type="button" class="btn-icon" phx-click="close_ctcp_settings_dialog">
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
