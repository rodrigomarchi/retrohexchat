defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.DisconnectConfirmDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.DisconnectConfirmDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Disconnect Confirm Dialog",
       active_page: "disconnect-confirm-dialog"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Disconnect Confirm Dialog</h2>

      <.showcase_card
        title="Disconnect from Server"
        description="Confirmation dialog shown before disconnecting from the IRC server."
      >
        <.button variant="destructive" phx-click={show_modal("disconnect-confirm")}>
          <:icon><Icons.icon_btn_disconnect class="w-4 h-4" /></:icon>
          Disconnect
        </.button>
        <.disconnect_confirm_dialog id="disconnect-confirm" />
        <.code_example>
          &lt;.disconnect_confirm_dialog
          id="disconnect-confirm"
          on_confirm=&#123;JS.push("disconnect_server")&#125;
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
