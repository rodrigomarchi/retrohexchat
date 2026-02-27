defmodule RetroHexChatWeb.Components.UI.HighlightDialog do
  @moduledoc """
  Highlight dialog component for the showcase design system.

  Composed from dialog + table + color_picker + button + input primitives.
  Word list with color assignments, Add/Edit/Remove.

  ## Usage

      <.highlight_dialog id="highlights" show={true} words={@words} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.ColorPicker
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @doc "Renders the highlight dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :words, :list, default: []
  attr :selected_color, :integer, default: nil

  @spec highlight_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def highlight_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header>
        <.dialog_icon>
          <Icons.icon_star class="w-4 h-4" />
        </.dialog_icon>
        <.dialog_title>Highlight Words</.dialog_title>
        <.dialog_close id={@id} />
      </.dialog_header>

      <.dialog_body class="space-y-retro-8">
        <%!-- Add word input --%>
        <div class="flex items-center gap-retro-4">
          <.input type="text" placeholder="Add word..." class="flex-1" />
          <.button size="sm" variant="outline">
            <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
            Add
          </.button>
        </div>

        <%!-- Word list table --%>
        <.table>
          <.table_header>
            <.table_row>
              <.table_head>Word</.table_head>
              <.table_head>Color</.table_head>
            </.table_row>
          </.table_header>
          <.table_body>
            <.table_row :for={word <- @words}>
              <.table_cell>{word.text}</.table_cell>
              <.table_cell>
                <div
                  class="w-4 h-4 border border-border"
                  style={"background-color: #{word.color}"}
                />
              </.table_cell>
            </.table_row>
          </.table_body>
        </.table>

        <div class="flex gap-retro-4">
          <.button size="sm" variant="outline">
            <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
            Edit
          </.button>
          <.button size="sm" variant="outline">
            <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
            Remove
          </.button>
        </div>

        <%!-- Color picker for assignment --%>
        <.color_picker id={"#{@id}-color-picker"} selected={@selected_color} />
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
