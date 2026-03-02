defmodule RetroHexChatWeb.Components.UI.CtcpSettingsDialog do
  @moduledoc """
  CTCP settings dialog component for the showcase design system.

  Composed from dialog + button + input + checkbox primitives.
  Form-based dialog matching v1 contract: fields `enabled`, `version_string`,
  `finger_text` submitted via `phx-submit`.

  ## Usage

      <.ctcp_settings_dialog
        id="ctcp-settings"
        show={true}
        settings={%{enabled: true, version_string: "RetroHexChat", finger_text: ""}}
        on_save="ctcp_save_settings"
        on_cancel="close_ctcp_settings_dialog"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Checkbox

  alias RetroHexChatWeb.Icons

  @doc "Renders the CTCP response settings dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :settings, :map,
    default: %{enabled: true, version_string: "RetroHexChat", finger_text: ""},
    doc: "CTCP settings map with keys: enabled, version_string, finger_text"

  attr :on_save, :any, default: nil, doc: "Form submit event name"
  attr :on_cancel, :any, default: nil, doc: "JS command or event name for cancel"

  @spec ctcp_settings_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def ctcp_settings_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header id={@id} title="CTCP Settings">
        <:icon><Icons.icon_dialog_ctcp class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
        <form phx-submit={@on_save}>
          <div class="space-y-retro-8" data-testid="ctcp-settings-dialog">
            <%!-- Hidden input for enabled (v1 pattern) --%>
            <input
              type="hidden"
              name="enabled"
              value={to_string(Map.get(@settings, :enabled, true))}
            />

            <%!-- Enable CTCP toggle --%>
            <div class="flex items-center gap-retro-4">
              <.checkbox
                id={"#{@id}-enabled"}
                name="enabled_checkbox"
                value={Map.get(@settings, :enabled, true)}
                phx-click={
                  Phoenix.LiveView.JS.dispatch("ctcp-toggle-enabled",
                    to: "##{@id} input[name=enabled]"
                  )
                }
                data-testid="ctcp-settings-enabled"
              />
              <label for={"#{@id}-enabled"} class="text-xs font-bold select-none cursor-pointer">
                Enable CTCP responses
              </label>
            </div>

            <%!-- Version reply --%>
            <div class="space-y-retro-2">
              <label for={"#{@id}-version"} class="text-xs font-bold">
                VERSION reply:
              </label>
              <.input
                id={"#{@id}-version"}
                name="version_string"
                type="text"
                value={Map.get(@settings, :version_string, "RetroHexChat")}
                placeholder="e.g. RetroHexChat 1.0"
                maxlength="200"
                class="text-xs h-7"
                data-testid="ctcp-settings-version"
              />
            </div>

            <%!-- Finger reply --%>
            <div class="space-y-retro-2">
              <label for={"#{@id}-finger"} class="text-xs font-bold">
                FINGER reply:
              </label>
              <.input
                id={"#{@id}-finger"}
                name="finger_text"
                type="text"
                value={Map.get(@settings, :finger_text, "")}
                placeholder="e.g. Just a user"
                maxlength="200"
                class="text-xs h-7"
                data-testid="ctcp-settings-finger"
              />
            </div>
          </div>

          <.dialog_footer>
            <.button type="submit" variant="default" data-testid="ctcp-settings-save">
              <:icon><Icons.icon_btn_save class="w-4 h-4" /></:icon>
              Save
            </.button>
            <.button
              type="button"
              variant="outline"
              phx-click={@on_cancel || hide_modal(@id)}
              data-testid="ctcp-settings-cancel"
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              Cancel
            </.button>
          </.dialog_footer>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end
end
