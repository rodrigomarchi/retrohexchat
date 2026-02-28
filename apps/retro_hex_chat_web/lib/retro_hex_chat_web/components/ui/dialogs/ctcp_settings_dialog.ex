defmodule RetroHexChatWeb.Components.UI.CtcpSettingsDialog do
  @moduledoc """
  CTCP settings dialog component for the showcase design system.

  Composed from dialog + button + input + checkbox primitives.
  Configures CTCP response settings: enable/disable, version/finger/time replies.

  ## Usage

      <.ctcp_settings_dialog
        id="ctcp-settings"
        show={true}
        settings={%{enabled: true, version_reply: "RetroHexChat", finger_reply: "", time_reply: ""}}
        on_save="save_ctcp"
        on_cancel="cancel_ctcp"
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
    default: %{enabled: true, version_reply: "RetroHexChat", finger_reply: "", time_reply: ""},
    doc: "CTCP settings map with keys: enabled, version_reply, finger_reply, time_reply"

  attr :on_save, :any, default: nil, doc: "JS command or event name for save"
  attr :on_cancel, :any, default: nil, doc: "JS command or event name for cancel"

  @spec ctcp_settings_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def ctcp_settings_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header id={@id} title="CTCP Settings">
        <:icon><Icons.icon_dialog_ctcp class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
        <div class="space-y-retro-8" data-testid="ctcp-settings-dialog">
          <%!-- Enable CTCP toggle --%>
          <div class="flex items-center gap-retro-4">
            <.checkbox
              id={"#{@id}-enabled"}
              name="ctcp_enabled"
              value={Map.get(@settings, :enabled, true)}
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
              name="ctcp_version_reply"
              type="text"
              value={Map.get(@settings, :version_reply, "RetroHexChat")}
              placeholder="e.g. RetroHexChat 1.0"
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
              name="ctcp_finger_reply"
              type="text"
              value={Map.get(@settings, :finger_reply, "")}
              placeholder="e.g. Just a user"
              class="text-xs h-7"
              data-testid="ctcp-settings-finger"
            />
          </div>

          <%!-- Time reply --%>
          <div class="space-y-retro-2">
            <label for={"#{@id}-time"} class="text-xs font-bold">
              TIME reply:
            </label>
            <.input
              id={"#{@id}-time"}
              name="ctcp_time_reply"
              type="text"
              value={Map.get(@settings, :time_reply, "")}
              placeholder="Leave blank for system time"
              class="text-xs h-7"
              data-testid="ctcp-settings-time"
            />
          </div>
        </div>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default" phx-click={@on_save} data-testid="ctcp-settings-save">
          <:icon><Icons.icon_btn_save class="w-4 h-4" /></:icon>
          Save
        </.button>
        <.button
          variant="outline"
          phx-click={@on_cancel || hide_modal(@id)}
          data-testid="ctcp-settings-cancel"
        >
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          Cancel
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end
end
