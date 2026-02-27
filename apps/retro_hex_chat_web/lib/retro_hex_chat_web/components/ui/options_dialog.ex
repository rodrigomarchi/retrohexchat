defmodule RetroHexChatWeb.Components.UI.OptionsDialog do
  @moduledoc """
  Options dialog component for the showcase design system.

  Composed from dialog + tree_view + tabs + form controls.
  Tree-view nav (left) + settings panel (right).

  ## Usage

      <.options_dialog id="options" show={true}>
        <:panel name="Display" icon="icon_tab_general">
          <p>Display settings here</p>
        </:panel>
      </.options_dialog>
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.TreeView
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders the options dialog with tree navigation."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :active_panel, :string, default: nil

  slot :panel, required: true do
    attr :name, :string, required: true
  end

  @spec options_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def options_dialog(assigns) do
    active = assigns.active_panel || List.first(assigns.panel)[:name]
    assigns = assign(assigns, :active, active)

    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header>
        <.dialog_icon>
          <Icons.icon_dialog_options class="w-4 h-4" />
        </.dialog_icon>
        <.dialog_title>Options</.dialog_title>
        <.dialog_close id={@id} />
      </.dialog_header>

      <.dialog_body class="flex gap-retro-8 min-h-[300px]">
        <%!-- Tree navigation --%>
        <.tree_view class="w-[160px] shrink-0">
          <.tree_view_item
            :for={panel <- @panel}
            active={panel.name == @active}
          >
            {panel.name}
          </.tree_view_item>
        </.tree_view>

        <%!-- Settings panel --%>
        <div class="flex-1 shadow-retro-field bg-white p-retro-8">
          <div :for={panel <- @panel} class={if(panel.name != @active, do: "hidden")}>
            <h3 class="font-bold text-xs mb-retro-8">{panel.name}</h3>
            {render_slot(panel)}
          </div>
        </div>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default">
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          OK
        </.button>
        <.button variant="outline" phx-click={hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          Cancel
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end
end
