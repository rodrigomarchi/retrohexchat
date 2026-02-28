defmodule RetroHexChatWeb.Components.UI.FloodProtectionDialog do
  @moduledoc """
  Flood protection settings dialog for the showcase design system.

  Composed from dialog + button + input primitives.
  Numeric input form for configuring message flood protection thresholds.

  ## Usage

      <.flood_protection_dialog
        id="flood-protection"
        show={true}
        settings={%{max_lines: 5, interval_ms: 2000, max_bytes: 512, penalty_ms: 5000}}
        on_save="flood_save"
        on_reset="flood_reset"
        on_cancel="flood_cancel"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @default_settings %{max_lines: 5, interval_ms: 2000, max_bytes: 512, penalty_ms: 5000}

  @doc "Renders the flood protection settings dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :settings, :map,
    default: @default_settings,
    doc: """
    Flood protection settings map.
    Keys: :max_lines (integer), :interval_ms (integer),
          :max_bytes (integer), :penalty_ms (integer).
    """

  attr :on_save, :any, default: nil, doc: "Save button callback"
  attr :on_reset, :any, default: nil, doc: "Reset Defaults button callback"
  attr :on_cancel, :any, default: nil, doc: "Cancel button callback"

  @spec flood_protection_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def flood_protection_dialog(assigns) do
    assigns = assign_new(assigns, :settings, fn -> @default_settings end)

    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header>
        <.dialog_icon>
          <Icons.icon_dialog_flood class="w-4 h-4" />
        </.dialog_icon>
        <.dialog_title>Flood Protection</.dialog_title>
        <.dialog_close id={@id} />
      </.dialog_header>

      <.dialog_body>
        <div class="space-y-retro-8">
          <p class="text-xs text-muted-foreground">
            Configure limits to prevent message flooding in channels and private messages.
          </p>

          <%!-- Max Lines --%>
          <div class="space-y-retro-2">
            <label class="text-xs font-bold block">Max Lines</label>
            <div class="flex items-center gap-retro-4">
              <.input
                id={"#{@id}-max-lines"}
                name="max_lines"
                type="number"
                value={Map.get(@settings, :max_lines, 5)}
                min="1"
                max="100"
                class="w-24 text-xs h-7"
              />
              <span class="text-xs text-muted-foreground">
                messages allowed per interval
              </span>
            </div>
          </div>

          <%!-- Interval (ms) --%>
          <div class="space-y-retro-2">
            <label class="text-xs font-bold block">Interval (ms)</label>
            <div class="flex items-center gap-retro-4">
              <.input
                id={"#{@id}-interval-ms"}
                name="interval_ms"
                type="number"
                value={Map.get(@settings, :interval_ms, 2000)}
                min="100"
                max="60000"
                step="100"
                class="w-24 text-xs h-7"
              />
              <span class="text-xs text-muted-foreground">
                milliseconds measurement window
              </span>
            </div>
          </div>

          <%!-- Max Bytes --%>
          <div class="space-y-retro-2">
            <label class="text-xs font-bold block">Max Bytes</label>
            <div class="flex items-center gap-retro-4">
              <.input
                id={"#{@id}-max-bytes"}
                name="max_bytes"
                type="number"
                value={Map.get(@settings, :max_bytes, 512)}
                min="64"
                max="8192"
                step="64"
                class="w-24 text-xs h-7"
              />
              <span class="text-xs text-muted-foreground">
                bytes per interval
              </span>
            </div>
          </div>

          <%!-- Penalty (ms) --%>
          <div class="space-y-retro-2">
            <label class="text-xs font-bold block">Penalty (ms)</label>
            <div class="flex items-center gap-retro-4">
              <.input
                id={"#{@id}-penalty-ms"}
                name="penalty_ms"
                type="number"
                value={Map.get(@settings, :penalty_ms, 5000)}
                min="500"
                max="300_000"
                step="500"
                class="w-24 text-xs h-7"
              />
              <span class="text-xs text-muted-foreground">
                delay applied when limit is exceeded
              </span>
            </div>
          </div>
        </div>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default" phx-click={@on_save}>
          <:icon><Icons.icon_btn_save class="w-4 h-4" /></:icon>
          Save
        </.button>
        <.button variant="outline" phx-click={@on_reset}>
          <:icon><Icons.icon_btn_reset class="w-4 h-4" /></:icon>
          Reset Defaults
        </.button>
        <.button variant="outline" phx-click={@on_cancel || hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          Cancel
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end
end
