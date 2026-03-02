defmodule RetroHexChatWeb.Components.UI.OptionsDialog do
  @moduledoc """
  Options dialog component for the showcase design system.

  Composed from dialog + tree_view + checkbox controls.
  Tree-view nav (left) + settings panel (right).
  Matches v1 contract: Display panel with checkboxes that fire
  `options_toggle_display` with `phx-value-setting`.

  ## Usage

      <.options_dialog
        id="options"
        show={true}
        options_draft={@options_draft}
        on_panel_select="options_select_panel"
        on_ok="options_ok"
        on_apply="options_apply"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.TreeView
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Checkbox

  alias RetroHexChatWeb.Icons

  @panels [
    {"display", "Display"}
  ]

  @doc "Renders the options dialog with tree navigation."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :active_panel, :string, default: "display"

  attr :options_draft, :map,
    default: nil,
    doc: "Draft state from options_events (has .display map)"

  attr :on_panel_select, :any, default: nil, doc: "Tree item click callback"
  attr :on_ok, :any, default: nil, doc: "OK button callback"
  attr :on_cancel, :any, default: nil, doc: "Cancel button callback (default: hide modal)"
  attr :on_apply, :any, default: nil, doc: "Apply button callback"

  # Keep the slot for backwards compatibility but it's no longer used for Display
  slot :panel do
    attr :name, :string, required: true
  end

  @spec options_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def options_dialog(assigns) do
    active = assigns.active_panel || "display"
    assigns = assign(assigns, :active, active)
    assigns = assign(assigns, :panels, @panels)

    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header id={@id} title="Options">
        <:icon><Icons.icon_dialog_options class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body class="flex gap-retro-8 min-h-[300px]">
        <%!-- Tree navigation --%>
        <.tree_view class="w-[160px] shrink-0">
          <.tree_view_item
            :for={{id, label} <- @panels}
            active={id == @active}
            phx-click={@on_panel_select}
            phx-value-panel={id}
          >
            {label}
          </.tree_view_item>
        </.tree_view>

        <%!-- Settings panel --%>
        <div class="flex-1 shadow-retro-field bg-white p-retro-8">
          <%!-- Display panel --%>
          <div class={if("display" != @active, do: "hidden")}>
            <h3 class="font-bold text-xs mb-retro-8">Display</h3>
            <.display_panel :if={@options_draft} draft={@options_draft} id={@id} />
            <p :if={!@options_draft} class="text-xs text-muted-foreground">
              Display settings
            </p>
          </div>

          <%!-- Slot-based panels (for future panels like messages, sounds) --%>
          <div
            :for={panel <- @panel}
            :if={panel.name != "display"}
            class={if(panel.name != @active, do: "hidden")}
          >
            <h3 class="font-bold text-xs mb-retro-8">{panel.name}</h3>
            {render_slot(panel)}
          </div>
        </div>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default" phx-click={@on_ok}>
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          OK
        </.button>
        <.button variant="outline" phx-click={@on_cancel || hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          Cancel
        </.button>
        <.button variant="outline" phx-click={@on_apply} disabled={@on_apply == nil}>
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          Apply
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end

  # ── Display Panel ─────────────────────────────────────────

  attr :draft, :map, required: true
  attr :id, :string, required: true

  @spec display_panel(map()) :: Phoenix.LiveView.Rendered.t()
  defp display_panel(assigns) do
    ~H"""
    <div data-testid="options-display-panel">
      <fieldset class="shadow-retro-field p-retro-8">
        <legend class="text-xs font-bold px-1">UI Elements</legend>
        <div class="space-y-retro-4">
          <.display_checkbox
            id={"#{@id}-show-toolbar"}
            label="Show Toolbar"
            checked={@draft.display.show_toolbar}
            setting="show_toolbar"
          />
          <.display_checkbox
            id={"#{@id}-show-conversations"}
            label="Show Conversations"
            checked={@draft.display.show_conversations}
            setting="show_conversations"
          />
          <.display_checkbox
            id={"#{@id}-show-switchbar"}
            label="Show Switchbar (Tab Bar)"
            checked={@draft.display.show_switchbar}
            setting="show_switchbar"
          />
          <.display_checkbox
            id={"#{@id}-show-statusbar"}
            label="Show Status Bar"
            checked={@draft.display.show_statusbar}
            setting="show_statusbar"
          />
        </div>
      </fieldset>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :checked, :boolean, required: true
  attr :setting, :string, required: true

  @spec display_checkbox(map()) :: Phoenix.LiveView.Rendered.t()
  defp display_checkbox(assigns) do
    ~H"""
    <div class="flex items-center gap-retro-4">
      <.checkbox
        id={@id}
        value={@checked}
        phx-click="options_toggle_display"
        phx-value-setting={@setting}
        data-testid={"options-display-#{@setting}"}
      />
      <label for={@id} class="text-xs select-none cursor-pointer">{@label}</label>
    </div>
    """
  end
end
