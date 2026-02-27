defmodule RetroHexChatWeb.Components.UI.AddressBook do
  @moduledoc """
  Address book dialog component for the showcase design system.

  Composed from dialog + table + button + color_picker primitives.
  Contact table with color grid, Add/Edit/Remove buttons.

  ## Usage

      <.address_book id="address-book" show={true} contacts={@contacts} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.ColorPicker

  alias RetroHexChatWeb.Icons

  @doc "Renders the address book dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :contacts, :list, default: []
  attr :selected_color, :integer, default: nil

  @spec address_book(map()) :: Phoenix.LiveView.Rendered.t()
  def address_book(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header>
        <.dialog_icon>
          <Icons.icon_dialog_address_book class="w-4 h-4" />
        </.dialog_icon>
        <.dialog_title>Address Book</.dialog_title>
        <.dialog_close id={@id} />
      </.dialog_header>

      <.dialog_body class="space-y-retro-8">
        <.table>
          <.table_header>
            <.table_row>
              <.table_head>Nick</.table_head>
              <.table_head>Notes</.table_head>
              <.table_head>Color</.table_head>
            </.table_row>
          </.table_header>
          <.table_body>
            <.table_row :for={contact <- @contacts}>
              <.table_cell>{contact.nick}</.table_cell>
              <.table_cell>{Map.get(contact, :notes, "")}</.table_cell>
              <.table_cell>
                <div
                  class="w-4 h-4 border border-border"
                  style={"background-color: #{Map.get(contact, :color, "#000")}"}
                />
              </.table_cell>
            </.table_row>
          </.table_body>
        </.table>

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

        <.color_picker id={"#{@id}-color-picker"} selected={@selected_color} />
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default" phx-click={hide_modal(@id)}>
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          Close
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end
end
