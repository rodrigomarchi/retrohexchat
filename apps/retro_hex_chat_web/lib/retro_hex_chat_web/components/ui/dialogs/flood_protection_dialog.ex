defmodule RetroHexChatWeb.Components.UI.FloodProtectionDialog do
  @moduledoc """
  Flood protection settings dialog for the showcase design system.

  Composed from dialog + button + input primitives.
  Form-based dialog matching v1 contract: 3 fieldsets (Message Flood,
  Anti-Spam, Auto-Ignore) with correct field names
  submitted via `phx-submit`.

  ## Usage

      <.flood_protection_dialog
        id="flood-protection"
        show={true}
        settings={%{flood_threshold: 5, flood_window_seconds: 10, spam_threshold: 3,
                     spam_window_seconds: 30, auto_ignore_duration_seconds: 60}}
        on_save="flood_save_settings"
        on_reset="flood_reset_defaults"
        on_cancel="close_flood_protection_dialog"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @default_settings %{
    flood_threshold: 5,
    flood_window_seconds: 10,
    spam_threshold: 3,
    spam_window_seconds: 30,
    auto_ignore_duration_seconds: 60
  }

  @doc "Renders the flood protection settings dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :settings, :map,
    default: @default_settings,
    doc: """
    Flood protection settings map.
    Keys: :flood_threshold, :flood_window_seconds,
          :spam_threshold, :spam_window_seconds,
          :auto_ignore_duration_seconds.
    """

  attr :on_save, :any, default: nil, doc: "Form submit event name"
  attr :on_reset, :any, default: nil, doc: "Reset Defaults button callback"
  attr :on_cancel, :any, default: nil, doc: "Cancel button callback"

  @spec flood_protection_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def flood_protection_dialog(assigns) do
    assigns = assign_new(assigns, :settings, fn -> @default_settings end)

    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header id={@id} title="Flood Protection">
        <:icon><Icons.icon_dialog_flood class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
        <form phx-submit={@on_save}>
          <div class="space-y-retro-8">
            <p class="text-xs text-muted-foreground">
              Configure limits to prevent message flooding in channels and private messages.
            </p>

            <%!-- Message Flood --%>
            <fieldset class="shadow-retro-field p-retro-8">
              <legend class="text-xs font-bold px-1">Message Flood</legend>
              <div class="space-y-retro-4">
                <div class="flex items-center gap-retro-4">
                  <label for={"#{@id}-threshold"} class="text-xs w-[120px]">Threshold:</label>
                  <.input
                    id={"#{@id}-threshold"}
                    name="flood_threshold"
                    type="number"
                    value={Map.get(@settings, :flood_threshold, 5)}
                    min="1"
                    max="100"
                    class="w-16 text-xs h-7"
                  />
                  <span class="text-xs text-muted-foreground">messages</span>
                </div>
                <div class="flex items-center gap-retro-4">
                  <label for={"#{@id}-window"} class="text-xs w-[120px]">Time window:</label>
                  <.input
                    id={"#{@id}-window"}
                    name="flood_window_seconds"
                    type="number"
                    value={Map.get(@settings, :flood_window_seconds, 10)}
                    min="1"
                    max="300"
                    class="w-16 text-xs h-7"
                  />
                  <span class="text-xs text-muted-foreground">seconds</span>
                </div>
              </div>
            </fieldset>

            <%!-- Anti-Spam --%>
            <fieldset class="shadow-retro-field p-retro-8">
              <legend class="text-xs font-bold px-1">Anti-Spam (Duplicate Detection)</legend>
              <div class="space-y-retro-4">
                <div class="flex items-center gap-retro-4">
                  <label for={"#{@id}-spam-threshold"} class="text-xs w-[120px]">
                    Duplicate limit:
                  </label>
                  <.input
                    id={"#{@id}-spam-threshold"}
                    name="spam_threshold"
                    type="number"
                    value={Map.get(@settings, :spam_threshold, 3)}
                    min="1"
                    max="50"
                    class="w-16 text-xs h-7"
                  />
                  <span class="text-xs text-muted-foreground">identical msgs</span>
                </div>
                <div class="flex items-center gap-retro-4">
                  <label for={"#{@id}-spam-window"} class="text-xs w-[120px]">Time window:</label>
                  <.input
                    id={"#{@id}-spam-window"}
                    name="spam_window_seconds"
                    type="number"
                    value={Map.get(@settings, :spam_window_seconds, 30)}
                    min="1"
                    max="120"
                    class="w-16 text-xs h-7"
                  />
                  <span class="text-xs text-muted-foreground">seconds</span>
                </div>
              </div>
            </fieldset>

            <%!-- Auto-Ignore --%>
            <fieldset class="shadow-retro-field p-retro-8">
              <legend class="text-xs font-bold px-1">Auto-Ignore</legend>
              <div class="flex items-center gap-retro-4">
                <label for={"#{@id}-ignore-duration"} class="text-xs w-[120px]">Duration:</label>
                <.input
                  id={"#{@id}-ignore-duration"}
                  name="auto_ignore_duration_seconds"
                  type="number"
                  value={Map.get(@settings, :auto_ignore_duration_seconds, 60)}
                  min="1"
                  max="86400"
                  class="w-20 text-xs h-7"
                />
                <span class="text-xs text-muted-foreground">seconds</span>
              </div>
            </fieldset>
          </div>

          <.dialog_footer>
            <.button type="submit" variant="default">
              <:icon><Icons.icon_btn_save class="w-4 h-4" /></:icon>
              Save
            </.button>
            <.button type="button" variant="outline" phx-click={@on_reset}>
              <:icon><Icons.icon_btn_reset class="w-4 h-4" /></:icon>
              Reset Defaults
            </.button>
            <.button type="button" variant="outline" phx-click={@on_cancel || hide_modal(@id)}>
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
