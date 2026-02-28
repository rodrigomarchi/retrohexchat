defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.FloodProtectionDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.FloodProtectionDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Flood Protection Dialog",
       active_page: "flood-protection-dialog"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Flood Protection Dialog</h2>

      <.showcase_card
        title="Default Settings"
        description="Flood protection with factory defaults: 5 lines per 2 s window, 512 bytes max, 5 s penalty."
      >
        <.button variant="outline" phx-click={show_modal("flood-default")}>
          <:icon><Icons.icon_dialog_flood class="w-4 h-4" /></:icon>
          Flood Protection (Defaults)
        </.button>
        <.flood_protection_dialog
          id="flood-default"
          settings={%{max_lines: 5, interval_ms: 2000, max_bytes: 512, penalty_ms: 5000}}
        />
        <.code_example>
          &lt;.flood_protection_dialog
          id="flood-protection"
          settings=&#123;%&#123;max_lines: 5, interval_ms: 2000, max_bytes: 512, penalty_ms: 5000&#125;&#125;
          on_save="flood_save"
          on_reset="flood_reset"
          on_cancel="flood_cancel"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Strict Settings"
        description="Tighter limits: 3 lines per 1 s, 256 bytes, 10 s penalty — suitable for high-traffic channels."
      >
        <.button variant="outline" phx-click={show_modal("flood-strict")}>
          <:icon><Icons.icon_dialog_flood class="w-4 h-4" /></:icon>
          Flood Protection (Strict)
        </.button>
        <.flood_protection_dialog
          id="flood-strict"
          settings={%{max_lines: 3, interval_ms: 1000, max_bytes: 256, penalty_ms: 10_000}}
        />
      </.showcase_card>

      <.showcase_card
        title="Lenient Settings"
        description="Relaxed limits: 20 lines per 5 s, 2048 bytes, 1 s penalty — for trusted environments."
      >
        <.button variant="outline" phx-click={show_modal("flood-lenient")}>
          <:icon><Icons.icon_dialog_flood class="w-4 h-4" /></:icon>
          Flood Protection (Lenient)
        </.button>
        <.flood_protection_dialog
          id="flood-lenient"
          settings={%{max_lines: 20, interval_ms: 5000, max_bytes: 2048, penalty_ms: 1000}}
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
