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
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @doc "Renders the address book dialog with 4 tabs."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :contacts, :list, default: [], doc: "List of %{nick, notes, color} maps"
  attr :notify_list, :list, default: [], doc: "List of %{nick, notify_on, notify_off} maps"
  attr :nick_colors, :list, default: [], doc: "List of %{nick, color} maps"
  attr :control_list, :list, default: [], doc: "List of ignore entries"
  attr :control_selected, :string, default: nil, doc: "Selected ignore entry nickname"
  attr :show_control_add_dialog, :boolean, default: false

  attr :selected_index, :any,
    default: nil,
    doc: "Currently selected row identifier (nickname or index)"

  attr :selected_tab, :string, default: "contacts", doc: "Active tab key"
  attr :show_contact_add_dialog, :boolean, default: false
  attr :show_contact_edit_dialog, :boolean, default: false
  attr :show_notify_add_dialog, :boolean, default: false
  attr :show_notify_edit_dialog, :boolean, default: false
  attr :show_nick_color_add_dialog, :boolean, default: false
  attr :show_nick_color_edit_dialog, :boolean, default: false
  attr :nick_color_fn, :any, default: nil, doc: "Function for nick color display"
  attr :timezone, :string, default: nil, doc: "Timezone for timestamps"
  attr :nick_palette_editing_index, :integer, default: nil, doc: "Color index in palette editor"
  attr :contacts_selected, :string, default: nil, doc: "Selected contact nick for edit form"
  attr :selected_contact_note, :string, default: "", doc: "Note for the selected contact (edit)"
  attr :notify_selected, :string, default: nil, doc: "Selected notify nick for edit form"
  attr :selected_notify_note, :string, default: "", doc: "Note for the selected notify (edit)"
  attr :nick_colors_selected, :string, default: nil, doc: "Selected nick color nick for edit"
  attr :on_select, :any, default: nil, doc: "Contacts tab row selection callback"
  attr :on_add, :any, default: nil, doc: "Contacts tab add button callback"
  attr :on_edit, :any, default: nil, doc: "Contacts tab edit button callback"
  attr :on_remove, :any, default: nil, doc: "Contacts tab remove button callback"
  attr :on_notify_select, :any, default: nil, doc: "Notify tab row selection callback"
  attr :on_notify_add, :any, default: nil, doc: "Notify tab add button callback"
  attr :on_notify_edit, :any, default: nil, doc: "Notify tab edit button callback"
  attr :on_notify_remove, :any, default: nil, doc: "Notify tab remove button callback"
  attr :on_nick_color_select, :any, default: nil, doc: "Nick Colors tab row selection callback"
  attr :on_nick_color_add, :any, default: nil, doc: "Nick Colors tab add button callback"
  attr :on_nick_color_edit, :any, default: nil, doc: "Nick Colors tab edit button callback"
  attr :on_nick_color_remove, :any, default: nil, doc: "Nick Colors tab remove button callback"
  attr :on_control_select, :any, default: nil, doc: "Control tab row selection callback"
  attr :on_control_add, :any, default: nil, doc: "Control tab add button callback"
  attr :on_control_remove, :any, default: nil, doc: "Control tab remove button callback"
  attr :on_tab, :any, default: nil, doc: "Tab selection callback"
  attr :on_ok, :any, default: nil, doc: "OK button callback"
  attr :on_cancel, :any, default: nil, doc: "Cancel button callback"
  attr :on_close, :any, default: nil, doc: "Close button callback"

  @spec address_book(map()) :: Phoenix.LiveView.Rendered.t()
  def address_book(assigns) do
    ~H"""
    <.dialog
      id={@id}
      show={@show}
      lock={
        @show_contact_add_dialog || @show_contact_edit_dialog ||
          @show_notify_add_dialog || @show_notify_edit_dialog ||
          @show_nick_color_add_dialog || @show_nick_color_edit_dialog ||
          @show_control_add_dialog
      }
      on_cancel={@on_close}
    >
      <.dialog_header id={@id} title="Address Book" on_close={@on_close}>
        <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body class="space-y-retro-8">
        <.tabs :let={builder} id={"#{@id}-tabs"} default={@selected_tab}>
          <.tabs_list class="flex-wrap">
            <.tabs_trigger
              builder={builder}
              value="contacts"
              phx-click={@on_tab}
              phx-value-tab="contacts"
            >
              <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
              Contacts
            </.tabs_trigger>
            <.tabs_trigger builder={builder} value="notify" phx-click={@on_tab} phx-value-tab="notify">
              <:icon><Icons.icon_btn_bell class="w-4 h-4" /></:icon>
              Notify
            </.tabs_trigger>
            <.tabs_trigger builder={builder} value="colors" phx-click={@on_tab} phx-value-tab="colors">
              <:icon><Icons.icon_fmt_color class="w-4 h-4" /></:icon>
              Nick Colors
            </.tabs_trigger>
            <.tabs_trigger
              builder={builder}
              value="control"
              phx-click={@on_tab}
              phx-value-tab="control"
            >
              <:icon><Icons.icon_shield class="w-4 h-4" /></:icon>
              Control
            </.tabs_trigger>
          </.tabs_list>

          <%!-- Contacts Tab --%>
          <.tabs_content value="contacts" builder={builder}>
            <.contacts_table
              contacts={@contacts}
              selected={if(@selected_tab == "contacts", do: @selected_index)}
              on_select={@on_select}
              nick_color_fn={@nick_color_fn}
              timezone={@timezone}
            />
            <.crud_buttons
              on_add={@on_add}
              on_edit={@on_edit}
              on_remove={@on_remove}
              selected={@selected_index != nil && @selected_tab == "contacts"}
              testid_prefix="contact"
            />
          </.tabs_content>

          <%!-- Notify Tab --%>
          <.tabs_content value="notify" builder={builder}>
            <.notify_table
              notify_list={@notify_list}
              selected={if(@selected_tab == "notify", do: @notify_selected)}
              on_select={@on_notify_select}
              timezone={@timezone}
            />
            <.crud_buttons
              on_add={@on_notify_add}
              on_edit={@on_notify_edit}
              on_remove={@on_notify_remove}
              selected={@notify_selected != nil && @selected_tab == "notify"}
              testid_prefix="ab-notify"
            />
          </.tabs_content>

          <%!-- Nick Colors Tab --%>
          <.tabs_content value="colors" builder={builder}>
            <.nick_colors_table
              nick_colors={@nick_colors}
              selected={if(@selected_tab == "colors", do: @nick_colors_selected)}
              on_select={@on_nick_color_select}
            />
            <.crud_buttons
              on_add={@on_nick_color_add}
              on_edit={@on_nick_color_edit}
              on_remove={@on_nick_color_remove}
              selected={@nick_colors_selected != nil && @selected_tab == "colors"}
              testid_prefix="nick-color"
            />
          </.tabs_content>

          <%!-- Control Tab --%>
          <.tabs_content value="control" builder={builder}>
            <.control_table
              control_list={@control_list}
              selected={if(@selected_tab == "control", do: @control_selected)}
              on_select={@on_control_select}
            />
            <div class="flex gap-retro-4 mt-retro-4">
              <.button
                size="sm"
                variant="outline"
                phx-click={@on_control_add}
                data-testid="control-add"
              >
                <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
                Add
              </.button>
              <.button
                size="sm"
                variant="outline"
                phx-click={@on_control_remove}
                disabled={@control_selected == nil}
                data-testid="control-remove"
              >
                <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
                Remove
              </.button>
            </div>
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

    <%!-- Contact Add Sub-Dialog --%>
    <.contact_add_form :if={@show_contact_add_dialog} />
    <%!-- Contact Edit Sub-Dialog --%>
    <.contact_edit_form
      :if={@show_contact_edit_dialog}
      contacts_selected={@contacts_selected}
      selected_contact_note={@selected_contact_note}
    />
    <%!-- Notify Add Sub-Dialog --%>
    <.ab_notify_add_form :if={@show_notify_add_dialog} />
    <%!-- Notify Edit Sub-Dialog --%>
    <.ab_notify_edit_form
      :if={@show_notify_edit_dialog}
      notify_selected={@notify_selected}
      selected_notify_note={@selected_notify_note}
    />
    <%!-- Nick Color Add Sub-Dialog --%>
    <.nick_color_add_form
      :if={@show_nick_color_add_dialog}
      nick_palette_editing_index={@nick_palette_editing_index}
    />
    <%!-- Nick Color Edit Sub-Dialog --%>
    <.nick_color_edit_form
      :if={@show_nick_color_edit_dialog}
      nick_colors_selected={@nick_colors_selected}
      nick_palette_editing_index={@nick_palette_editing_index}
    />
    <%!-- Control Add Sub-Dialog --%>
    <.control_add_form :if={@show_control_add_dialog} />
    """
  end

  # ── Sub-Forms ──────────────────────────────────────────

  defp contact_add_form(assigns) do
    ~H"""
    <div class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center">
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-sm">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">Add Contact</span>
          <div class="ml-auto">
            <button type="button" aria-label="Close" phx-click="contact_add_cancel" />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="contact_add" data-testid="contact-add-form">
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="contact-add-nick">Nickname:</label>
              <.input
                type="text"
                id="contact-add-nick"
                name="nickname"
                maxlength="16"
                required
                autocomplete="off"
                class="w-full"
              />
            </div>
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="contact-add-note">Notes:</label>
              <textarea
                id="contact-add-note"
                name="note"
                maxlength="200"
                rows="3"
                class="textarea-resizable w-full"
              />
            </div>
            <div class="flex justify-end gap-2">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                OK
              </.button>
              <.button type="button" size="sm" variant="outline" phx-click="contact_add_cancel">
                <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                Cancel
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  attr :contacts_selected, :string, default: nil
  attr :selected_contact_note, :string, default: ""

  defp contact_edit_form(assigns) do
    ~H"""
    <div class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center">
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-sm">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">Edit Contact</span>
          <div class="ml-auto">
            <button type="button" aria-label="Close" phx-click="contact_edit_cancel" />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="contact_edit" data-testid="contact-edit-form">
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="contact-edit-nick">Nickname:</label>
              <.input
                type="text"
                id="contact-edit-nick"
                name="nickname"
                value={@contacts_selected}
                readonly
                class="w-full input-readonly"
              />
            </div>
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="contact-edit-note">Notes:</label>
              <.input
                type="text"
                id="contact-edit-note"
                name="note"
                value={@selected_contact_note}
                maxlength="200"
                class="w-full"
              />
            </div>
            <div class="flex justify-end gap-2">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                OK
              </.button>
              <.button type="button" size="sm" variant="outline" phx-click="contact_edit_cancel">
                <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                Cancel
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp ab_notify_add_form(assigns) do
    ~H"""
    <div class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center">
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-sm">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">Add Notify Entry</span>
          <div class="ml-auto">
            <button type="button" aria-label="Close" phx-click="notify_add_cancel" />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="notify_add" data-testid="ab-notify-add-form">
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="ab-notify-add-nick">Nickname:</label>
              <.input
                type="text"
                id="ab-notify-add-nick"
                name="nickname"
                maxlength="16"
                required
                class="w-full"
              />
            </div>
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="ab-notify-add-note">Note:</label>
              <.input
                type="text"
                id="ab-notify-add-note"
                name="note"
                maxlength="200"
                class="w-full"
              />
            </div>
            <div class="flex justify-end gap-2">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                OK
              </.button>
              <.button type="button" size="sm" variant="outline" phx-click="notify_add_cancel">
                <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                Cancel
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  attr :notify_selected, :string, default: nil
  attr :selected_notify_note, :string, default: ""

  defp ab_notify_edit_form(assigns) do
    ~H"""
    <div class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center">
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-sm">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">Edit Notify Entry</span>
          <div class="ml-auto">
            <button type="button" aria-label="Close" phx-click="notify_edit_cancel" />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="notify_edit" data-testid="ab-notify-edit-form">
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="ab-notify-edit-nick">Nickname:</label>
              <.input
                type="text"
                id="ab-notify-edit-nick"
                name="nickname"
                value={@notify_selected}
                readonly
                class="w-full input-readonly"
              />
            </div>
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="ab-notify-edit-note">Note:</label>
              <.input
                type="text"
                id="ab-notify-edit-note"
                name="note"
                value={@selected_notify_note}
                maxlength="200"
                class="w-full"
              />
            </div>
            <div class="flex justify-end gap-2">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                OK
              </.button>
              <.button type="button" size="sm" variant="outline" phx-click="notify_edit_cancel">
                <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                Cancel
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  attr :nick_palette_editing_index, :integer, default: nil

  defp nick_color_add_form(assigns) do
    ~H"""
    <div class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center">
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-sm">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">Add Nick Color</span>
          <div class="ml-auto">
            <button type="button" aria-label="Close" phx-click="nick_color_add_cancel" />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="nick_color_add" data-testid="nick-color-add-form">
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="nick-color-add-nick">Nickname:</label>
              <.input
                type="text"
                id="nick-color-add-nick"
                name="nickname"
                maxlength="16"
                required
                class="w-full"
              />
            </div>
            <input
              type="hidden"
              name="color_index"
              value={to_string(@nick_palette_editing_index || "")}
            />
            <div class="flex flex-col gap-1.5 mb-3">
              <label class="text-xs font-bold">Color:</label>
              <.color_picker
                id="nick-color-add-picker"
                selected={@nick_palette_editing_index}
                on_select="nick_palette_pick"
              />
            </div>
            <div class="flex justify-end gap-2">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                OK
              </.button>
              <.button
                type="button"
                size="sm"
                variant="outline"
                phx-click="nick_color_add_cancel"
              >
                <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                Cancel
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  attr :nick_colors_selected, :string, default: nil
  attr :nick_palette_editing_index, :integer, default: nil

  defp nick_color_edit_form(assigns) do
    ~H"""
    <div class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center">
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-sm">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">Edit Nick Color</span>
          <div class="ml-auto">
            <button type="button" aria-label="Close" phx-click="nick_color_edit_cancel" />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="nick_color_edit" data-testid="nick-color-edit-form">
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="nick-color-edit-nick">Nickname:</label>
              <.input
                type="text"
                id="nick-color-edit-nick"
                name="nickname"
                value={@nick_colors_selected}
                readonly
                class="w-full input-readonly"
              />
            </div>
            <input
              type="hidden"
              name="color_index"
              value={to_string(@nick_palette_editing_index || "")}
            />
            <div class="flex flex-col gap-1.5 mb-3">
              <label class="text-xs font-bold">Color:</label>
              <.color_picker
                id="nick-color-edit-picker"
                selected={@nick_palette_editing_index}
                on_select="nick_palette_pick"
              />
            </div>
            <div class="flex justify-end gap-2">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                OK
              </.button>
              <.button
                type="button"
                size="sm"
                variant="outline"
                phx-click="nick_color_edit_cancel"
              >
                <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                Cancel
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # ── Contacts Table ──────────────────────────────────

  attr :contacts, :list, required: true
  attr :selected, :any, default: nil
  attr :on_select, :any, default: nil
  attr :nick_color_fn, :any, default: nil
  attr :timezone, :string, default: nil

  defp contacts_table(assigns) do
    ~H"""
    <.table>
      <.table_header>
        <.table_row>
          <.table_head>Nick</.table_head>
          <.table_head>Notes</.table_head>
          <.table_head>Since</.table_head>
        </.table_row>
      </.table_header>
      <.table_body>
        <.table_row :if={@contacts == []}>
          <.table_cell colspan="3" class="text-center text-muted-foreground py-4">
            No contacts saved
          </.table_cell>
        </.table_row>
        <.table_row
          :for={contact <- @contacts}
          id={"contact-entry-#{contact.contact_nickname}"}
          class={
            if(@selected == contact.contact_nickname,
              do: "bg-selection-bg text-selection-fg",
              else: ""
            )
          }
          phx-click={@on_select}
          phx-value-nickname={contact.contact_nickname}
        >
          <.table_cell>
            <span class={@nick_color_fn && @nick_color_fn.(contact.contact_nickname)}>
              {contact.contact_nickname}
            </span>
          </.table_cell>
          <.table_cell>{Map.get(contact, :note, "")}</.table_cell>
          <.table_cell class="text-xs text-muted-foreground">
            {format_contact_date(Map.get(contact, :first_contact_date), @timezone)}
          </.table_cell>
        </.table_row>
      </.table_body>
    </.table>
    """
  end

  # ── Notify Table ────────────────────────────────────

  attr :notify_list, :list, required: true
  attr :selected, :any, default: nil
  attr :on_select, :any, default: nil
  attr :timezone, :string, default: nil

  defp notify_table(assigns) do
    ~H"""
    <.table>
      <.table_header>
        <.table_row>
          <.table_head>Nick</.table_head>
          <.table_head>Status</.table_head>
          <.table_head>Note</.table_head>
          <.table_head>Last Seen</.table_head>
        </.table_row>
      </.table_header>
      <.table_body>
        <.table_row :if={@notify_list == []}>
          <.table_cell colspan="4" class="text-center text-muted-foreground py-4">
            No entries. Click Add to track a nickname.
          </.table_cell>
        </.table_row>
        <.table_row
          :for={entry <- @notify_list}
          id={"ab-notify-entry-#{entry.tracked_nickname}"}
          class={
            if(@selected == entry.tracked_nickname, do: "bg-selection-bg text-selection-fg", else: "")
          }
          phx-click={@on_select}
          phx-value-nickname={entry.tracked_nickname}
        >
          <.table_cell>{entry.tracked_nickname}</.table_cell>
          <.table_cell>
            <span class={if(entry.online, do: "text-success", else: "text-muted-foreground")}>
              {if entry.online, do: "Online", else: "Offline"}
            </span>
          </.table_cell>
          <.table_cell class="text-xs">{Map.get(entry, :note, "")}</.table_cell>
          <.table_cell class="text-xs text-muted-foreground">
            {format_last_seen(Map.get(entry, :last_seen_at), entry.online, @timezone)}
          </.table_cell>
        </.table_row>
      </.table_body>
    </.table>
    """
  end

  # ── Nick Colors Table ───────────────────────────────

  attr :nick_colors, :list, required: true
  attr :selected, :any, default: nil
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
        <.table_row :if={@nick_colors == []}>
          <.table_cell colspan="2" class="text-center text-muted-foreground py-4">
            No custom colors set. Nicknames use automatic colors.
          </.table_cell>
        </.table_row>
        <.table_row
          :for={entry <- @nick_colors}
          id={"nick-color-entry-#{entry.target_nickname}"}
          data-color-index={entry.color_index}
          class={
            if(@selected == entry.target_nickname, do: "bg-selection-bg text-selection-fg", else: "")
          }
          phx-click={@on_select}
          phx-value-nickname={entry.target_nickname}
        >
          <.table_cell>{entry.target_nickname}</.table_cell>
          <.table_cell>
            <div
              class="w-4 h-4 border border-border"
              class={nick_color_class(entry.color_index)}
            />
          </.table_cell>
        </.table_row>
      </.table_body>
    </.table>
    """
  end

  # ── Control Table ───────────────────────────────────

  attr :control_list, :list, required: true
  attr :selected, :any, default: nil
  attr :on_select, :any, default: nil

  defp control_table(assigns) do
    ~H"""
    <.table>
      <.table_header>
        <.table_row>
          <.table_head>Nick</.table_head>
          <.table_head>Type</.table_head>
          <.table_head>Expires</.table_head>
        </.table_row>
      </.table_header>
      <.table_body>
        <.table_row :if={@control_list == []}>
          <.table_cell colspan="3" class="text-center text-muted-foreground py-4">
            No ignored users. Click Add to ignore a nickname.
          </.table_cell>
        </.table_row>
        <.table_row
          :for={entry <- @control_list}
          id={"control-entry-#{control_nick(entry)}"}
          class={
            if(@selected == control_nick(entry), do: "bg-selection-bg text-selection-fg", else: "")
          }
          phx-click={@on_select}
          phx-value-nickname={control_nick(entry)}
        >
          <.table_cell class="font-bold text-xs">{control_nick(entry)}</.table_cell>
          <.table_cell class="text-xs">
            {to_string(Map.get(entry, :ignore_type, Map.get(entry, :level, "")))}
          </.table_cell>
          <.table_cell class="text-xs text-muted-foreground">
            {format_expires(Map.get(entry, :expires_at))}
          </.table_cell>
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
  attr :testid_prefix, :string, default: nil

  defp crud_buttons(assigns) do
    ~H"""
    <div class="flex gap-retro-4 mt-retro-4">
      <.button
        size="sm"
        variant="outline"
        phx-click={@on_add}
        data-testid={@testid_prefix && "#{@testid_prefix}-add"}
      >
        <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
        Add
      </.button>
      <.button
        size="sm"
        variant="outline"
        phx-click={@on_edit}
        disabled={!@selected}
        data-testid={@testid_prefix && "#{@testid_prefix}-edit"}
      >
        <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
        Edit
      </.button>
      <.button
        size="sm"
        variant="outline"
        phx-click={@on_remove}
        disabled={!@selected}
        data-testid={@testid_prefix && "#{@testid_prefix}-remove"}
      >
        <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
        Remove
      </.button>
    </div>
    """
  end

  # ── Control Add Sub-Form ────────────────────────────

  defp control_add_form(assigns) do
    ~H"""
    <div class="fixed inset-0 z-modal-above bg-black/50 flex items-center justify-center">
      <div class="bg-surface shadow-retro-window p-[3px] w-full max-w-sm">
        <div class="bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2">
          <span class="text-xs font-bold text-white truncate select-none">Add Ignore Entry</span>
          <div class="ml-auto">
            <button type="button" aria-label="Close" phx-click="control_add_cancel" />
          </div>
        </div>
        <div class="p-2">
          <form phx-submit="control_add_confirm" data-testid="control-add-form">
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="control-add-nick">Nickname:</label>
              <.input
                type="text"
                id="control-add-nick"
                name="nickname"
                maxlength="16"
                required
                autocomplete="off"
                class="w-full"
              />
            </div>
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="control-add-type">Type:</label>
              <select id="control-add-type" name="type" class="w-full">
                <option value="all" selected>All</option>
                <option value="messages">Messages</option>
                <option value="pms">PMs</option>
                <option value="actions">Actions</option>
                <option value="notices">Notices</option>
                <option value="invites">Invites</option>
              </select>
            </div>
            <div class="flex flex-col gap-1.5 mb-2">
              <label class="text-xs font-bold" for="control-add-duration">
                Duration (leave empty for permanent):
              </label>
              <.input
                type="text"
                id="control-add-duration"
                name="duration"
                placeholder="e.g. 5m, 1h, 2d"
                autocomplete="off"
                class="w-full"
              />
            </div>
            <div class="flex justify-end gap-2">
              <.button type="submit" size="sm">
                <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                OK
              </.button>
              <.button type="button" size="sm" variant="outline" phx-click="control_add_cancel">
                <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                Cancel
              </.button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # ── Helpers ────────────────────────────────────────

  # Support both IgnoreEntry structs (:nickname) and showcase maps (:nick)
  @spec control_nick(map()) :: String.t()
  defp control_nick(entry), do: Map.get(entry, :nickname) || Map.get(entry, :nick, "")

  @spec nick_color_class(any()) :: String.t()
  defp nick_color_class(n) when is_integer(n), do: "irc-bg-#{n}"
  defp nick_color_class(_), do: "bg-black"

  @spec format_contact_date(DateTime.t() | nil, String.t() | nil) :: String.t()
  defp format_contact_date(nil, _timezone), do: ""

  defp format_contact_date(dt, timezone) do
    dt
    |> shift_timezone(timezone)
    |> Calendar.strftime("%d/%m/%Y")
  end

  @spec format_last_seen(DateTime.t() | nil, boolean(), String.t() | nil) :: String.t()
  defp format_last_seen(_dt, true, _timezone), do: "—"
  defp format_last_seen(nil, false, _timezone), do: "Never"

  defp format_last_seen(dt, false, timezone) do
    dt
    |> shift_timezone(timezone)
    |> Calendar.strftime("%d/%m %H:%M")
  end

  @spec format_expires(DateTime.t() | nil) :: String.t()
  defp format_expires(nil), do: "Permanent"

  defp format_expires(dt) do
    remaining = DateTime.diff(dt, DateTime.utc_now(), :second)

    cond do
      remaining <= 0 -> "Expired"
      remaining < 60 -> "#{remaining}s"
      remaining < 3600 -> "#{div(remaining, 60)}m"
      remaining < 86_400 -> "#{div(remaining, 3600)}h"
      true -> "#{div(remaining, 86_400)}d"
    end
  end

  @spec shift_timezone(DateTime.t(), String.t() | nil) :: DateTime.t()
  defp shift_timezone(dt, nil), do: dt
  defp shift_timezone(dt, "Etc/UTC"), do: dt

  defp shift_timezone(dt, timezone) do
    case DateTime.shift_zone(dt, timezone) do
      {:ok, shifted} -> shifted
      {:error, _} -> dt
    end
  end
end
