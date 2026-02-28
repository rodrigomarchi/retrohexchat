defmodule RetroHexChatWeb.Components.UI.AddressBook do
  @moduledoc """
  Address book dialog component for the showcase design system.

  Composed from dialog + tabs + table + button + color_picker primitives.
  Four tabs: Contacts, Notify, Nick Colors, Control.
  Each tab has a table with Add/Edit/Remove buttons and row selection.

  ## Usage

      <.address_book
        id="address-book"
        show={true}
        contacts={@contacts}
        on_select="ab-select"
        on_add="ab-add"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.ColorPicker

  alias RetroHexChatWeb.Icons

  @doc "Renders the address book dialog with 4 tabs."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :contacts, :list, default: [], doc: "List of %{nick, notes, color} maps"
  attr :notify_list, :list, default: [], doc: "List of %{nick, notify_on, notify_off} maps"
  attr :nick_colors, :list, default: [], doc: "List of %{nick, color} maps"
  attr :control_list, :list, default: [], doc: "List of %{nick, level} maps"
  attr :selected_index, :integer, default: nil, doc: "Currently selected row index"
  attr :selected_tab, :string, default: "contacts", doc: "Active tab key"
  attr :selected_color, :integer, default: nil
  attr :on_select, :any, default: nil, doc: "Row selection callback (receives phx-value-index)"
  attr :on_add, :any, default: nil, doc: "Add button callback"
  attr :on_edit, :any, default: nil, doc: "Edit button callback"
  attr :on_remove, :any, default: nil, doc: "Remove button callback"
  attr :on_color_select, :any, default: nil, doc: "Color select callback"
  attr :on_ok, :any, default: nil, doc: "OK button callback"
  attr :on_cancel, :any, default: nil, doc: "Cancel button callback"
  attr :on_close, :any, default: nil, doc: "Close button callback"

  @spec address_book(map()) :: Phoenix.LiveView.Rendered.t()
  def address_book(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header id={@id} title="Address Book">
        <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body class="space-y-retro-8">
        <.tabs :let={builder} id={"#{@id}-tabs"} default={@selected_tab}>
          <.tabs_list>
            <.tabs_trigger builder={builder} value="contacts">
              <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
              Contacts
            </.tabs_trigger>
            <.tabs_trigger builder={builder} value="notify">
              <:icon><Icons.icon_btn_bell class="w-4 h-4" /></:icon>
              Notify
            </.tabs_trigger>
            <.tabs_trigger builder={builder} value="colors">
              <:icon><Icons.icon_fmt_color class="w-4 h-4" /></:icon>
              Nick Colors
            </.tabs_trigger>
            <.tabs_trigger builder={builder} value="control">
              <:icon><Icons.icon_shield class="w-4 h-4" /></:icon>
              Control
            </.tabs_trigger>
          </.tabs_list>

          <%!-- Contacts Tab --%>
          <.tabs_content value="contacts">
            <.contacts_table
              contacts={@contacts}
              selected_index={if(@selected_tab == "contacts", do: @selected_index)}
              on_select={@on_select}
            />
            <.crud_buttons
              on_add={@on_add}
              on_edit={@on_edit}
              on_remove={@on_remove}
              selected={@selected_index != nil && @selected_tab == "contacts"}
            />
            <.color_picker
              id={"#{@id}-color-picker"}
              selected={@selected_color}
              on_select={@on_color_select}
            />
          </.tabs_content>

          <%!-- Notify Tab --%>
          <.tabs_content value="notify">
            <.notify_table
              notify_list={@notify_list}
              selected_index={if(@selected_tab == "notify", do: @selected_index)}
              on_select={@on_select}
            />
            <.crud_buttons
              on_add={@on_add}
              on_edit={@on_edit}
              on_remove={@on_remove}
              selected={@selected_index != nil && @selected_tab == "notify"}
            />
          </.tabs_content>

          <%!-- Nick Colors Tab --%>
          <.tabs_content value="colors">
            <.nick_colors_table
              nick_colors={@nick_colors}
              selected_index={if(@selected_tab == "colors", do: @selected_index)}
              on_select={@on_select}
            />
            <.crud_buttons
              on_add={@on_add}
              on_edit={@on_edit}
              on_remove={@on_remove}
              selected={@selected_index != nil && @selected_tab == "colors"}
            />
            <.color_picker
              id={"#{@id}-nick-color-picker"}
              selected={@selected_color}
              on_select={@on_color_select}
            />
          </.tabs_content>

          <%!-- Control Tab --%>
          <.tabs_content value="control">
            <.control_table
              control_list={@control_list}
              selected_index={if(@selected_tab == "control", do: @selected_index)}
              on_select={@on_select}
            />
            <.crud_buttons
              on_add={@on_add}
              on_edit={@on_edit}
              on_remove={@on_remove}
              selected={@selected_index != nil && @selected_tab == "control"}
            />
          </.tabs_content>
        </.tabs>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default" phx-click={@on_ok || hide_modal(@id)}>
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          OK
        </.button>
        <.button variant="outline" phx-click={@on_cancel || hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          Cancel
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end

  # ── Contacts Table ──────────────────────────────────

  attr :contacts, :list, required: true
  attr :selected_index, :integer, default: nil
  attr :on_select, :any, default: nil

  defp contacts_table(assigns) do
    ~H"""
    <.table>
      <.table_header>
        <.table_row>
          <.table_head>Nick</.table_head>
          <.table_head>Notes</.table_head>
          <.table_head>Color</.table_head>
        </.table_row>
      </.table_header>
      <.table_body>
        <.table_row
          :for={{contact, idx} <- Enum.with_index(@contacts)}
          class={if(@selected_index == idx, do: "bg-selection-bg text-selection-fg", else: "")}
          phx-click={@on_select}
          phx-value-index={idx}
        >
          <.table_cell>{contact.nick}</.table_cell>
          <.table_cell>{Map.get(contact, :notes, "")}</.table_cell>
          <.table_cell>
            <div
              class="w-4 h-4 border border-border"
              class={nick_color_class(Map.get(contact, :color))}
            />
          </.table_cell>
        </.table_row>
      </.table_body>
    </.table>
    """
  end

  # ── Notify Table ────────────────────────────────────

  attr :notify_list, :list, required: true
  attr :selected_index, :integer, default: nil
  attr :on_select, :any, default: nil

  defp notify_table(assigns) do
    ~H"""
    <.table>
      <.table_header>
        <.table_row>
          <.table_head>Nick</.table_head>
          <.table_head>On Join</.table_head>
          <.table_head>On Part</.table_head>
        </.table_row>
      </.table_header>
      <.table_body>
        <.table_row
          :for={{entry, idx} <- Enum.with_index(@notify_list)}
          class={if(@selected_index == idx, do: "bg-selection-bg text-selection-fg", else: "")}
          phx-click={@on_select}
          phx-value-index={idx}
        >
          <.table_cell>{entry.nick}</.table_cell>
          <.table_cell>{if Map.get(entry, :notify_on, true), do: "Yes", else: "No"}</.table_cell>
          <.table_cell>{if Map.get(entry, :notify_off, true), do: "Yes", else: "No"}</.table_cell>
        </.table_row>
      </.table_body>
    </.table>
    """
  end

  # ── Nick Colors Table ───────────────────────────────

  attr :nick_colors, :list, required: true
  attr :selected_index, :integer, default: nil
  attr :on_select, :any, default: nil

  defp nick_colors_table(assigns) do
    ~H"""
    <.table>
      <.table_header>
        <.table_row>
          <.table_head>Nick</.table_head>
          <.table_head>Color</.table_head>
        </.table_row>
      </.table_header>
      <.table_body>
        <.table_row
          :for={{entry, idx} <- Enum.with_index(@nick_colors)}
          class={if(@selected_index == idx, do: "bg-selection-bg text-selection-fg", else: "")}
          phx-click={@on_select}
          phx-value-index={idx}
        >
          <.table_cell>{entry.nick}</.table_cell>
          <.table_cell>
            <div
              class="w-4 h-4 border border-border"
              class={nick_color_class(Map.get(entry, :color))}
            />
          </.table_cell>
        </.table_row>
      </.table_body>
    </.table>
    """
  end

  # ── Control Table ───────────────────────────────────

  attr :control_list, :list, required: true
  attr :selected_index, :integer, default: nil
  attr :on_select, :any, default: nil

  defp control_table(assigns) do
    ~H"""
    <.table>
      <.table_header>
        <.table_row>
          <.table_head>Nick</.table_head>
          <.table_head>Level</.table_head>
        </.table_row>
      </.table_header>
      <.table_body>
        <.table_row
          :for={{entry, idx} <- Enum.with_index(@control_list)}
          class={if(@selected_index == idx, do: "bg-selection-bg text-selection-fg", else: "")}
          phx-click={@on_select}
          phx-value-index={idx}
        >
          <.table_cell>{entry.nick}</.table_cell>
          <.table_cell>{Map.get(entry, :level, "normal")}</.table_cell>
        </.table_row>
      </.table_body>
    </.table>
    """
  end

  # ── CRUD Buttons ────────────────────────────────────

  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :selected, :boolean, default: false

  defp crud_buttons(assigns) do
    ~H"""
    <div class="flex gap-retro-4 mt-retro-4">
      <.button size="sm" variant="outline" phx-click={@on_add}>
        <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
        Add
      </.button>
      <.button size="sm" variant="outline" phx-click={@on_edit} disabled={!@selected}>
        <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
        Edit
      </.button>
      <.button size="sm" variant="outline" phx-click={@on_remove} disabled={!@selected}>
        <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
        Remove
      </.button>
    </div>
    """
  end

  @spec nick_color_class(any()) :: String.t()
  defp nick_color_class(n) when is_integer(n), do: "irc-bg-#{n}"
  defp nick_color_class(_), do: "bg-black"
end
