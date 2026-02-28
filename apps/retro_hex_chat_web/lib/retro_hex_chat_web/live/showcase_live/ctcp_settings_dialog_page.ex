defmodule RetroHexChatWeb.ShowcaseLive.CtcpSettingsDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.CtcpSettingsDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "CTCP Settings Dialog", active_page: "ctcp-settings-dialog")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">CTCP Settings Dialog</h2>

      <.showcase_card
        title="Enabled State"
        description="CTCP responses enabled with version, finger, and time replies configured."
      >
        <.button variant="outline" phx-click={show_modal("ctcp-enabled")}>
          <:icon><Icons.icon_dialog_ctcp class="w-4 h-4" /></:icon>
          Open CTCP Settings (Enabled)
        </.button>
        <.ctcp_settings_dialog
          id="ctcp-enabled"
          settings={
            %{
              enabled: true,
              version_reply: "RetroHexChat 1.0",
              finger_reply: "Just a user",
              time_reply: ""
            }
          }
        />
        <.code_example>
          &lt;.ctcp_settings_dialog
          id="ctcp-settings"
          settings=&#123;%&#123;enabled: true, version_reply: "RetroHexChat 1.0", finger_reply: "", time_reply: ""&#125;&#125;
          on_save="save_ctcp"
          on_cancel="cancel_ctcp"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Disabled State"
        description="CTCP responses disabled — checkbox unchecked, fields still visible."
      >
        <.button variant="outline" phx-click={show_modal("ctcp-disabled")}>
          <:icon><Icons.icon_dialog_ctcp class="w-4 h-4" /></:icon>
          Open CTCP Settings (Disabled)
        </.button>
        <.ctcp_settings_dialog
          id="ctcp-disabled"
          settings={
            %{
              enabled: false,
              version_reply: "",
              finger_reply: "",
              time_reply: ""
            }
          }
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
