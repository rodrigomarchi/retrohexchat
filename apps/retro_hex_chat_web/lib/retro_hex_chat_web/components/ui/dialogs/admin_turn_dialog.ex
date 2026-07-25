defmodule RetroHexChatWeb.Components.UI.AdminTurnDialog do
  @moduledoc """
  Admin TURN window — relay telemetry for the WebRTC TURN server.

  Read-only. Two panes, one refresh: there is nothing here an admin can change,
  only observe.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AdminShared
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :target, :any, default: nil
  attr :stats, :string, default: nil
  attr :allocations, :string, default: nil
  attr :result, :any, default: nil
  attr :can_refresh, :boolean, default: false
  attr :on_refresh, :any, default: nil
  attr :on_cancel, :any, default: nil

  @doc "Framed variant with dialog chrome — used by the showcase page."
  @spec admin_turn_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_turn_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="max-w-2xl">
      <.dialog_header id={@id} title={dgettext("dialogs", "TURN")} on_close={@on_cancel}>
        <:icon><Icons.icon_websocket class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.admin_turn_panel {assigns} />
      </.dialog_body>
    </.dialog>
    """
  end

  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :stats, :string, default: nil
  attr :allocations, :string, default: nil
  attr :result, :any, default: nil
  attr :can_refresh, :boolean, default: false
  attr :on_refresh, :any, default: nil

  @spec admin_turn_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_turn_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-content"}
      data-testid="admin-turn-panel"
      class="adm-dialog flex h-full min-h-0 flex-col gap-retro-8"
    >
      <div class="adm-scroll min-h-0 flex-1 overflow-y-auto">
        <div class="space-y-retro-8">
          <div class="flex justify-end">
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click={@on_refresh}
              phx-target={@target}
              disabled={not @can_refresh}
            >
              <:icon><Icons.icon_btn_refresh class="w-[14px] h-[14px]" /></:icon>
              {dgettext("dialogs", "Refresh")}
            </.button>
          </div>

          <div class="grid gap-retro-8 md:grid-cols-2">
            <div>
              <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "Stats")}</div>
              <pre
                id="admin-turn-stats"
                class="shadow-retro-sunken bg-white min-h-[168px] max-h-[220px] overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap"
              ><%= @stats || "" %></pre>
            </div>
            <div>
              <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "Allocations")}</div>
              <pre
                id="admin-turn-allocations"
                class="shadow-retro-sunken bg-white min-h-[168px] max-h-[220px] overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap"
              ><%= @allocations || "" %></pre>
            </div>
          </div>

          <.inline_result result={@result} />
        </div>
      </div>
    </div>
    """
  end
end
