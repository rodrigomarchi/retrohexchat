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

  @doc """
  Renders the address book content (4 tabs + the seven add/edit sub-form
  modals, window-scoped) without any frame — compose it inside a desktop
  window body.
  """
  attr :id, :string, required: true
  attr :target, :any, default: nil
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

  @spec address_book_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def address_book_panel(assigns) do
    ~H"""
    <div id={@id} class="contents">
      <.focus_wrap id={"#{@id}-focus-wrap"} class="contents">
        <div
          id={"#{@id}-content"}
          data-testid="address-book-panel"
          role="dialog"
          aria-modal="false"
          tabindex="0"
          phx-mounted={JS.focus(to: "##{@id}-content")}
          class="ab-dialog flex h-full min-h-0 flex-col gap-retro-8"
        >
          <.tabs :let={builder} id={"#{@id}-tabs"} default={@selected_tab} class="ab-tabs min-h-0">
            <div class="ab-tabs-shell">
              <.tabs_list class="ab-main-tabs flex-wrap">
                <.tabs_trigger
                  builder={builder}
                  value="contacts"
                  phx-click={@on_tab}
                  phx-value-tab="contacts"
                >
                  <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Contacts")}
                </.tabs_trigger>
                <.tabs_trigger
                  builder={builder}
                  value="notify"
                  phx-click={@on_tab}
                  phx-value-tab="notify"
                >
                  <:icon><Icons.icon_btn_bell class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Notify")}
                </.tabs_trigger>
                <.tabs_trigger
                  builder={builder}
                  value="colors"
                  phx-click={@on_tab}
                  phx-value-tab="colors"
                >
                  <:icon><Icons.icon_fmt_color class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Nick Colors")}
                </.tabs_trigger>
                <.tabs_trigger
                  builder={builder}
                  value="control"
                  phx-click={@on_tab}
                  phx-value-tab="control"
                >
                  <:icon><Icons.icon_shield class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Control")}
                </.tabs_trigger>
              </.tabs_list>
            </div>

            <%!-- Contacts Tab --%>
            <.tabs_content value="contacts" builder={builder} class="ab-tab-content">
              <.contacts_table
                target={@target}
                contacts={@contacts}
                selected={if(@selected_tab == "contacts", do: @selected_index)}
                on_select={@on_select}
                nick_color_fn={@nick_color_fn}
                timezone={@timezone}
              />
              <.crud_buttons
                target={@target}
                on_add={@on_add}
                on_edit={@on_edit}
                on_remove={@on_remove}
                selected={@selected_index != nil && @selected_tab == "contacts"}
                testid_prefix="contact"
              />
            </.tabs_content>

            <%!-- Notify Tab --%>
            <.tabs_content value="notify" builder={builder} class="ab-tab-content">
              <.notify_table
                target={@target}
                notify_list={@notify_list}
                selected={if(@selected_tab == "notify", do: @notify_selected)}
                on_select={@on_notify_select}
                timezone={@timezone}
              />
              <.crud_buttons
                target={@target}
                on_add={@on_notify_add}
                on_edit={@on_notify_edit}
                on_remove={@on_notify_remove}
                selected={@notify_selected != nil && @selected_tab == "notify"}
                testid_prefix="ab-notify"
              />
            </.tabs_content>

            <%!-- Nick Colors Tab --%>
            <.tabs_content value="colors" builder={builder} class="ab-tab-content">
              <.nick_colors_table
                target={@target}
                nick_colors={@nick_colors}
                selected={if(@selected_tab == "colors", do: @nick_colors_selected)}
                on_select={@on_nick_color_select}
              />
              <.crud_buttons
                target={@target}
                on_add={@on_nick_color_add}
                on_edit={@on_nick_color_edit}
                on_remove={@on_nick_color_remove}
                selected={@nick_colors_selected != nil && @selected_tab == "colors"}
                testid_prefix="nick-color"
              />
            </.tabs_content>

            <%!-- Control Tab --%>
            <.tabs_content value="control" builder={builder} class="ab-tab-content">
              <.control_table
                target={@target}
                control_list={@control_list}
                selected={if(@selected_tab == "control", do: @control_selected)}
                on_select={@on_control_select}
              />
              <div class="ab-action-row flex gap-retro-4 mt-retro-4">
                <.button
                  size="sm"
                  variant="outline"
                  phx-click={@on_control_add}
                  phx-target={@target}
                  data-testid="control-add"
                  class="ab-action-button"
                >
                  <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Add")}
                </.button>
                <.button
                  size="sm"
                  variant="outline"
                  phx-click={@on_control_remove}
                  phx-target={@target}
                  disabled={@control_selected == nil}
                  data-testid="control-remove"
                  class="ab-action-button"
                >
                  <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
                  {dgettext("dialogs", "Remove")}
                </.button>
              </div>
            </.tabs_content>
          </.tabs>

          <%!-- Contact Add Sub-Dialog --%>
          <.contact_add_form :if={@show_contact_add_dialog} target={@target} />
          <%!-- Contact Edit Sub-Dialog --%>
          <.contact_edit_form
            :if={@show_contact_edit_dialog}
            target={@target}
            contacts_selected={@contacts_selected}
            selected_contact_note={@selected_contact_note}
          />
          <%!-- Notify Add Sub-Dialog --%>
          <.ab_notify_add_form :if={@show_notify_add_dialog} target={@target} />
          <%!-- Notify Edit Sub-Dialog --%>
          <.ab_notify_edit_form
            :if={@show_notify_edit_dialog}
            target={@target}
            notify_selected={@notify_selected}
            selected_notify_note={@selected_notify_note}
          />
          <%!-- Nick Color Add Sub-Dialog --%>
          <.nick_color_add_form
            :if={@show_nick_color_add_dialog}
            target={@target}
            nick_palette_editing_index={@nick_palette_editing_index}
          />
          <%!-- Nick Color Edit Sub-Dialog --%>
          <.nick_color_edit_form
            :if={@show_nick_color_edit_dialog}
            target={@target}
            nick_colors_selected={@nick_colors_selected}
            nick_palette_editing_index={@nick_palette_editing_index}
          />
          <%!-- Control Add Sub-Dialog --%>
          <.control_add_form :if={@show_control_add_dialog} target={@target} />
        </div>
      </.focus_wrap>
    </div>
    """
  end

  # ── Sub-Forms ──────────────────────────────────────────

  attr :target, :any, default: nil

  defp contact_add_form(assigns) do
    ~H"""
    <.dialog
      id="ab-contact-add-modal"
      show
      scope={:window}
      on_cancel={JS.push("contact_add_cancel", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="ab-contact-add-modal"
        title={dgettext("dialogs", "Add Contact")}
        on_close={JS.push("contact_add_cancel", target: @target)}
      >
        <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form phx-submit="contact_add" phx-target={@target} data-testid="contact-add-form">
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="contact-add-nick">
              {dgettext("dialogs", "Nickname")}:
            </label>
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
            <label class="text-xs font-bold" for="contact-add-note">
              {dgettext("dialogs", "Notes")}:
            </label>
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
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="contact_add_cancel"
              phx-target={@target}
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  attr :target, :any, default: nil
  attr :contacts_selected, :string, default: nil
  attr :selected_contact_note, :string, default: ""

  defp contact_edit_form(assigns) do
    ~H"""
    <.dialog
      id="ab-contact-edit-modal"
      show
      scope={:window}
      on_cancel={JS.push("contact_edit_cancel", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="ab-contact-edit-modal"
        title={dgettext("dialogs", "Edit Contact")}
        on_close={JS.push("contact_edit_cancel", target: @target)}
      >
        <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form phx-submit="contact_edit" phx-target={@target} data-testid="contact-edit-form">
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="contact-edit-nick">
              {dgettext("dialogs", "Nickname")}:
            </label>
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
            <label class="text-xs font-bold" for="contact-edit-note">
              {dgettext("dialogs", "Notes")}:
            </label>
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
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="contact_edit_cancel"
              phx-target={@target}
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  attr :target, :any, default: nil

  defp ab_notify_add_form(assigns) do
    ~H"""
    <.dialog
      id="ab-notify-add-modal"
      show
      scope={:window}
      on_cancel={JS.push("notify_add_cancel", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="ab-notify-add-modal"
        title={dgettext("dialogs", "Add Notify Entry")}
        on_close={JS.push("notify_add_cancel", target: @target)}
      >
        <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form phx-submit="notify_add" phx-target={@target} data-testid="ab-notify-add-form">
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="ab-notify-add-nick">
              {dgettext("dialogs", "Nickname")}:
            </label>
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
            <label class="text-xs font-bold" for="ab-notify-add-note">
              {dgettext("dialogs", "Note")}:
            </label>
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
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="notify_add_cancel"
              phx-target={@target}
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  attr :target, :any, default: nil
  attr :notify_selected, :string, default: nil
  attr :selected_notify_note, :string, default: ""

  defp ab_notify_edit_form(assigns) do
    ~H"""
    <.dialog
      id="ab-notify-edit-modal"
      show
      scope={:window}
      on_cancel={JS.push("notify_edit_cancel", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="ab-notify-edit-modal"
        title={dgettext("dialogs", "Edit Notify Entry")}
        on_close={JS.push("notify_edit_cancel", target: @target)}
      >
        <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form phx-submit="notify_edit" phx-target={@target} data-testid="ab-notify-edit-form">
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="ab-notify-edit-nick">
              {dgettext("dialogs", "Nickname")}:
            </label>
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
            <label class="text-xs font-bold" for="ab-notify-edit-note">
              {dgettext("dialogs", "Note")}:
            </label>
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
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="notify_edit_cancel"
              phx-target={@target}
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  attr :target, :any, default: nil
  attr :nick_palette_editing_index, :integer, default: nil

  defp nick_color_add_form(assigns) do
    ~H"""
    <.dialog
      id="ab-nick-color-add-modal"
      show
      scope={:window}
      on_cancel={JS.push("nick_color_add_cancel", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="ab-nick-color-add-modal"
        title={dgettext("dialogs", "Add Nick Color")}
        on_close={JS.push("nick_color_add_cancel", target: @target)}
      >
        <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form phx-submit="nick_color_add" phx-target={@target} data-testid="nick-color-add-form">
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="nick-color-add-nick">
              {dgettext("dialogs", "Nickname")}:
            </label>
            <.input
              type="text"
              id="nick-color-add-nick"
              name="nickname"
              maxlength="16"
              required
              phx-update="ignore"
              class="w-full"
            />
          </div>
          <input
            type="hidden"
            name="color_index"
            value={to_string(@nick_palette_editing_index || "")}
          />
          <div class="flex flex-col gap-1.5 mb-3">
            <label class="text-xs font-bold">{dgettext("dialogs", "Color")}:</label>
            <.color_picker
              id="nick-color-add-picker"
              selected={@nick_palette_editing_index}
              on_select="nick_palette_pick"
              target={@target}
            />
          </div>
          <div class="flex justify-end gap-2">
            <.button type="submit" size="sm">
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="nick_color_add_cancel"
              phx-target={@target}
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  attr :target, :any, default: nil
  attr :nick_colors_selected, :string, default: nil
  attr :nick_palette_editing_index, :integer, default: nil

  defp nick_color_edit_form(assigns) do
    ~H"""
    <.dialog
      id="ab-nick-color-edit-modal"
      show
      scope={:window}
      on_cancel={JS.push("nick_color_edit_cancel", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="ab-nick-color-edit-modal"
        title={dgettext("dialogs", "Edit Nick Color")}
        on_close={JS.push("nick_color_edit_cancel", target: @target)}
      >
        <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form phx-submit="nick_color_edit" phx-target={@target} data-testid="nick-color-edit-form">
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="nick-color-edit-nick">
              {dgettext("dialogs", "Nickname")}:
            </label>
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
            <label class="text-xs font-bold">{dgettext("dialogs", "Color")}:</label>
            <.color_picker
              id="nick-color-edit-picker"
              selected={@nick_palette_editing_index}
              on_select="nick_palette_pick"
              target={@target}
            />
          </div>
          <div class="flex justify-end gap-2">
            <.button type="submit" size="sm">
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="nick_color_edit_cancel"
              phx-target={@target}
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  # ── Contacts Table ──────────────────────────────────

  attr :target, :any, default: nil
  attr :contacts, :list, required: true
  attr :selected, :any, default: nil
  attr :on_select, :any, default: nil
  attr :nick_color_fn, :any, default: nil
  attr :timezone, :string, default: nil

  defp contacts_table(assigns) do
    ~H"""
    <div class="ab-table-wrap">
      <.table class="ab-mobile-list-table">
        <.table_header>
          <.table_row>
            <.table_head>{dgettext("dialogs", "Nick")}</.table_head>
            <.table_head>{dgettext("dialogs", "Notes")}</.table_head>
            <.table_head>{dgettext("dialogs", "Since")}</.table_head>
          </.table_row>
        </.table_header>
        <.table_body>
          <.table_row :if={@contacts == []} class="ab-empty-row">
            <.table_cell colspan="3" class="ab-empty-cell text-center text-muted-foreground py-4">
              {dgettext("dialogs", "No contacts saved")}
            </.table_cell>
          </.table_row>
          <.table_row
            :for={contact <- @contacts}
            id={"contact-entry-#{contact.contact_nickname}"}
            class={row_class("ab-mobile-list-row", @selected == contact.contact_nickname)}
            phx-click={@on_select}
            phx-target={@target}
            phx-value-nickname={contact.contact_nickname}
          >
            <.table_cell
              class="ab-mobile-list-primary"
              data-label={dgettext("dialogs", "Nick")}
            >
              <span class={@nick_color_fn && @nick_color_fn.(contact.contact_nickname)}>
                {contact.contact_nickname}
              </span>
            </.table_cell>
            <.table_cell class="ab-mobile-list-meta" data-label={dgettext("dialogs", "Notes")}>
              {Map.get(contact, :note, "")}
            </.table_cell>
            <.table_cell
              class="ab-mobile-list-meta text-xs text-muted-foreground"
              data-label={dgettext("dialogs", "Since")}
            >
              {format_contact_date(Map.get(contact, :first_contact_date), @timezone)}
            </.table_cell>
          </.table_row>
        </.table_body>
      </.table>
    </div>
    """
  end

  # ── Notify Table ────────────────────────────────────

  attr :target, :any, default: nil
  attr :notify_list, :list, required: true
  attr :selected, :any, default: nil
  attr :on_select, :any, default: nil
  attr :timezone, :string, default: nil

  defp notify_table(assigns) do
    ~H"""
    <div class="ab-entry-list" role="list">
      <div :if={@notify_list == []} class="ab-entry-empty">
        {dgettext("dialogs", "No entries. Click Add to track a nickname.")}
      </div>
      <button
        :for={entry <- @notify_list}
        id={"ab-notify-entry-#{entry.tracked_nickname}"}
        type="button"
        class={row_class("ab-entry", @selected == entry.tracked_nickname)}
        phx-click={@on_select}
        phx-target={@target}
        phx-value-nickname={entry.tracked_nickname}
        role="listitem"
      >
        <span class="ab-entry-primary">
          <span class="ab-entry-label">{dgettext("dialogs", "Nick")}</span>
          <span class="ab-entry-value">{entry.tracked_nickname}</span>
        </span>
        <span class="ab-entry-meta">
          <span class="ab-entry-label">{dgettext("dialogs", "Status")}</span>
          <span class={
            if(entry.online,
              do: "ab-entry-value text-success",
              else: "ab-entry-value text-muted-foreground"
            )
          }>
            {if entry.online,
              do: dgettext("dialogs", "Online"),
              else: dgettext("dialogs", "Offline")}
          </span>
        </span>
        <span class="ab-entry-meta">
          <span class="ab-entry-label">{dgettext("dialogs", "Note")}</span>
          <span class="ab-entry-value">{Map.get(entry, :note, "")}</span>
        </span>
        <span class="ab-entry-meta">
          <span class="ab-entry-label">{dgettext("dialogs", "Last Seen")}</span>
          <span class="ab-entry-value text-muted-foreground">
            {format_last_seen(Map.get(entry, :last_seen_at), entry.online, @timezone)}
          </span>
        </span>
      </button>
    </div>
    """
  end

  # ── Nick Colors Table ───────────────────────────────

  attr :target, :any, default: nil
  attr :nick_colors, :list, required: true
  attr :selected, :any, default: nil
  attr :on_select, :any, default: nil

  defp nick_colors_table(assigns) do
    ~H"""
    <div class="ab-table-wrap">
      <.table class="ab-mobile-list-table">
        <.table_header>
          <.table_row>
            <.table_head>{dgettext("dialogs", "Nick")}</.table_head>
            <.table_head>{dgettext("dialogs", "Color")}</.table_head>
          </.table_row>
        </.table_header>
        <.table_body>
          <.table_row :if={@nick_colors == []} class="ab-empty-row">
            <.table_cell colspan="2" class="ab-empty-cell text-center text-muted-foreground py-4">
              {dgettext("dialogs", "No custom colors set. Nicknames use automatic colors.")}
            </.table_cell>
          </.table_row>
          <.table_row
            :for={entry <- @nick_colors}
            id={"nick-color-entry-#{entry.target_nickname}"}
            data-color-index={entry.color_index}
            class={row_class("ab-mobile-list-row", @selected == entry.target_nickname)}
            phx-click={@on_select}
            phx-target={@target}
            phx-value-nickname={entry.target_nickname}
          >
            <.table_cell
              class="ab-mobile-list-primary"
              data-label={dgettext("dialogs", "Nick")}
            >
              {entry.target_nickname}
            </.table_cell>
            <.table_cell class="ab-mobile-list-meta" data-label={dgettext("dialogs", "Color")}>
              <div class={"ab-color-swatch w-4 h-4 border border-border #{nick_color_class(entry.color_index)}"} />
            </.table_cell>
          </.table_row>
        </.table_body>
      </.table>
    </div>
    """
  end

  # ── Control Table ───────────────────────────────────

  attr :target, :any, default: nil
  attr :control_list, :list, required: true
  attr :selected, :any, default: nil
  attr :on_select, :any, default: nil

  defp control_table(assigns) do
    ~H"""
    <div class="ab-table-wrap">
      <.table class="ab-mobile-list-table">
        <.table_header>
          <.table_row>
            <.table_head>{dgettext("dialogs", "Nick")}</.table_head>
            <.table_head>{dgettext("dialogs", "Type")}</.table_head>
            <.table_head>{dgettext("dialogs", "Expires")}</.table_head>
          </.table_row>
        </.table_header>
        <.table_body>
          <.table_row :if={@control_list == []} class="ab-empty-row">
            <.table_cell colspan="3" class="ab-empty-cell text-center text-muted-foreground py-4">
              {dgettext("dialogs", "No ignored users. Click Add to ignore a nickname.")}
            </.table_cell>
          </.table_row>
          <.table_row
            :for={entry <- @control_list}
            id={"control-entry-#{control_nick(entry)}"}
            class={row_class("ab-mobile-list-row", @selected == control_nick(entry))}
            phx-click={@on_select}
            phx-target={@target}
            phx-value-nickname={control_nick(entry)}
          >
            <.table_cell
              class="ab-mobile-list-primary font-bold text-xs"
              data-label={dgettext("dialogs", "Nick")}
            >
              {control_nick(entry)}
            </.table_cell>
            <.table_cell
              class="ab-mobile-list-meta text-xs"
              data-label={dgettext("dialogs", "Type")}
            >
              {to_string(Map.get(entry, :ignore_type, Map.get(entry, :level, "")))}
            </.table_cell>
            <.table_cell
              class="ab-mobile-list-meta text-xs text-muted-foreground"
              data-label={dgettext("dialogs", "Expires")}
            >
              {format_expires(Map.get(entry, :expires_at))}
            </.table_cell>
          </.table_row>
        </.table_body>
      </.table>
    </div>
    """
  end

  # ── CRUD Buttons ────────────────────────────────────

  attr :target, :any, default: nil
  attr :on_add, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :selected, :boolean, default: false
  attr :testid_prefix, :string, default: nil

  defp crud_buttons(assigns) do
    ~H"""
    <div class="ab-action-row flex gap-retro-4 mt-retro-4">
      <.button
        size="sm"
        variant="outline"
        phx-click={@on_add}
        phx-target={@target}
        data-testid={@testid_prefix && "#{@testid_prefix}-add"}
        class="ab-action-button"
      >
        <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
        {dgettext("dialogs", "Add")}
      </.button>
      <.button
        size="sm"
        variant="outline"
        phx-click={@on_edit}
        phx-target={@target}
        disabled={!@selected}
        data-testid={@testid_prefix && "#{@testid_prefix}-edit"}
        class="ab-action-button"
      >
        <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
        {dgettext("dialogs", "Edit")}
      </.button>
      <.button
        size="sm"
        variant="outline"
        phx-click={@on_remove}
        phx-target={@target}
        disabled={!@selected}
        data-testid={@testid_prefix && "#{@testid_prefix}-remove"}
        class="ab-action-button"
      >
        <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
        {dgettext("dialogs", "Remove")}
      </.button>
    </div>
    """
  end

  # ── Control Add Sub-Form ────────────────────────────

  attr :target, :any, default: nil

  defp control_add_form(assigns) do
    ~H"""
    <.dialog
      id="ab-control-add-modal"
      show
      scope={:window}
      on_cancel={JS.push("control_add_cancel", target: @target)}
      class="md:max-w-sm"
    >
      <.dialog_header
        id="ab-control-add-modal"
        title={dgettext("dialogs", "Add Ignore Entry")}
        on_close={JS.push("control_add_cancel", target: @target)}
      >
        <:icon><Icons.icon_dialog_address_book class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form phx-submit="control_add_confirm" phx-target={@target} data-testid="control-add-form">
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="control-add-nick">
              {dgettext("dialogs", "Nickname")}:
            </label>
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
            <label class="text-xs font-bold" for="control-add-type">
              {dgettext("dialogs", "Type")}:
            </label>
            <select id="control-add-type" name="type" class="w-full">
              <option value="all" selected>{dgettext("dialogs", "All")}</option>
              <option value="messages">{dgettext("dialogs", "Messages")}</option>
              <option value="pms">{dgettext("dialogs", "PMs")}</option>
              <option value="actions">{dgettext("dialogs", "Actions")}</option>
              <option value="notices">{dgettext("dialogs", "Notices")}</option>
              <option value="invites">{dgettext("dialogs", "Invites")}</option>
            </select>
          </div>
          <div class="flex flex-col gap-1.5 mb-2">
            <label class="text-xs font-bold" for="control-add-duration">
              {dgettext("dialogs", "Duration (leave empty for permanent)")}:
            </label>
            <.input
              type="text"
              id="control-add-duration"
              name="duration"
              placeholder={dgettext("dialogs", "e.g. 5m, 1h, 2d")}
              autocomplete="off"
              class="w-full"
            />
          </div>
          <div class="flex justify-end gap-2">
            <.button type="submit" size="sm">
              <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click="control_add_cancel"
              phx-target={@target}
            >
              <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  # ── Helpers ────────────────────────────────────────

  defp row_class(base, true), do: "#{base} bg-selection-bg text-selection-fg"
  defp row_class(base, false), do: base

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
  defp format_last_seen(nil, false, _timezone), do: dgettext("dialogs", "Never")

  defp format_last_seen(dt, false, timezone) do
    dt
    |> shift_timezone(timezone)
    |> Calendar.strftime("%d/%m %H:%M")
  end

  @spec format_expires(DateTime.t() | nil) :: String.t()
  defp format_expires(nil), do: dgettext("dialogs", "Permanent")

  defp format_expires(dt) do
    remaining = DateTime.diff(dt, DateTime.utc_now(), :second)

    cond do
      remaining <= 0 -> dgettext("dialogs", "Expired")
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
