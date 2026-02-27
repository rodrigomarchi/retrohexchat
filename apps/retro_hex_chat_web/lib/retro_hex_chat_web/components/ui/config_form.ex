defmodule RetroHexChatWeb.Components.UI.ConfigForm do
  @moduledoc """
  Config form dialog component for the showcase design system.

  Composed from dialog + table + button + form controls.
  Generic config pattern: list (left) + edit form (right).
  Reusable base for Alias, Perform, Flood Protection, CTCP, Sound Settings.

  ## Usage

      <.config_form
        id="alias-config"
        title="Aliases"
        items={[%{name: "/hi", value: "/msg $1 hello!"}]}
      >
        <:form>
          <.input type="text" placeholder="Alias name" />
          <.input type="text" placeholder="Alias value" />
        </:form>
      </.config_form>
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders the config form dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :title, :string, default: "Configuration"
  attr :items, :list, default: []
  attr :columns, :list, default: ["Name", "Value"]

  slot :form

  @spec config_form(map()) :: Phoenix.LiveView.Rendered.t()
  def config_form(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header>
        <.dialog_icon>
          <Icons.icon_btn_settings class="w-4 h-4" />
        </.dialog_icon>
        <.dialog_title>{@title}</.dialog_title>
        <.dialog_close id={@id} />
      </.dialog_header>

      <.dialog_body class="flex gap-retro-8 min-h-[250px]">
        <%!-- List side --%>
        <div class="flex-1 space-y-retro-4">
          <div class="max-h-[200px] overflow-y-auto retro-scrollbar">
            <.table>
              <.table_header>
                <.table_row>
                  <.table_head :for={col <- @columns}>{col}</.table_head>
                </.table_row>
              </.table_header>
              <.table_body>
                <.table_row :for={item <- @items}>
                  <.table_cell>{item.name}</.table_cell>
                  <.table_cell>{Map.get(item, :value, "")}</.table_cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>

          <div class="flex gap-retro-4">
            <.button size="sm" variant="outline">
              <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
              Add
            </.button>
            <.button size="sm" variant="outline">
              <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
              Edit
            </.button>
            <.button size="sm" variant="outline">
              <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
              Remove
            </.button>
          </div>
        </div>

        <%!-- Edit form side --%>
        <div :if={@form != []} class="w-[200px] shrink-0 shadow-retro-field bg-white p-retro-8 space-y-retro-8">
          <h3 class="font-bold text-xs mb-retro-4">Edit</h3>
          {render_slot(@form)}
        </div>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default" phx-click={hide_modal(@id)}>
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
