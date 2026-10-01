defmodule RetroHexChatWeb.Components.UI.AddressBook do
  @moduledoc """
  Address book dialog component for the showcase design system.

  Composed from dialog + table + button primitives: the saved-contacts list with
  Add/Edit/Remove and row selection. Nick colors and the ignore list are their
  own windows; notify tracking lives in the Notify List window.

  ## Usage

      <.address_book_panel
        id="address-book"
        contacts={@contacts}
        on_add="contact_add_dialog"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ActionList
  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.DialogBanner

  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Icons

  @doc """
  Renders the address book content (the contacts table plus its two window-scoped
  add/edit sub-form modals) without any frame — compose it inside a desktop
  window body.
  """
  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :contacts, :list, default: [], doc: "List of contact entries"
  attr :selected, :string, default: nil, doc: "Selected contact nickname"
  attr :show_contact_add_dialog, :boolean, default: false
  attr :show_contact_edit_dialog, :boolean, default: false
  attr :nick_color_fn, :any, default: nil, doc: "Function for nick color display"
  attr :timezone, :string, default: nil, doc: "Timezone for timestamps"
  attr :selected_contact_note, :string, default: "", doc: "Note for the selected contact (edit)"
  attr :on_add, :any, default: nil, doc: "Add button callback"
  attr :on_edit, :any, default: nil, doc: "Edit button callback"
  attr :on_remove, :any, default: nil, doc: "Remove button callback"

  @spec address_book_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def address_book_panel(assigns) do
    assigns = assign(assigns, :contact_lines, contact_lines(assigns.contacts))

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
          <.dialog_banner heading={dgettext("dialogs", "The people you keep a note on")}>
            <:art>
              <Diagrams.diagram_dialog_preview
                kind={:card}
                title={dgettext("dialogs", "Whois")}
                lines={@contact_lines}
                label={dgettext("dialogs", "A miniature of the card a contact is read on")}
              />
            </:art>
            <:glyph><Icons.icon_dialog_address_book class="h-8 w-8" /></:glyph>
            {dgettext(
              "dialogs",
              "A contact is yours alone: the nickname, the colour you gave it and your own note. Nobody is told you added them, and nothing here reaches the server they see."
            )}
          </.dialog_banner>

          <.contacts_table
            target={@target}
            contacts={@contacts}
            on_edit={@on_edit}
            on_remove={@on_remove}
            nick_color_fn={@nick_color_fn}
            timezone={@timezone}
          />
          <.add_button target={@target} on_add={@on_add} testid_prefix="contact" />

          <%!-- Contact Add Sub-Dialog --%>
          <.contact_add_form :if={@show_contact_add_dialog} target={@target} />
          <%!-- Contact Edit Sub-Dialog --%>
          <.contact_edit_form
            :if={@show_contact_edit_dialog}
            target={@target}
            contacts_selected={@selected}
            selected_contact_note={@selected_contact_note}
          />
        </div>
      </.focus_wrap>
    </div>
    """
  end

  # ── Sub-Forms ──────────────────────────────────────────

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
  attr :contacts, :list, required: true
  attr :on_edit, :any, default: nil
  attr :on_remove, :any, default: nil
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
            <.table_head class="ab-mobile-list-action-head">
              <span class="sr-only">{dgettext("dialogs", "Actions")}</span>
            </.table_head>
          </.table_row>
        </.table_header>
        <.table_body>
          <.table_row :if={@contacts == []} class="ab-empty-row">
            <.table_cell colspan="4" class="ab-empty-cell text-center text-muted-foreground py-4">
              {dgettext("dialogs", "No contacts saved")}
            </.table_cell>
          </.table_row>
          <.table_row
            :for={contact <- @contacts}
            id={"contact-entry-#{contact.contact_nickname}"}
            class="ab-mobile-list-row"
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
            <.table_cell class="ab-mobile-list-action">
              <.row_action
                event={@on_edit}
                value={%{"nickname" => contact.contact_nickname}}
                label={dgettext("dialogs", "Edit %{nickname}", nickname: contact.contact_nickname)}
                target={@target}
                testid={"contact-edit-#{contact.contact_nickname}"}
              >
                <Icons.icon_btn_edit class="w-4 h-4" />
              </.row_action>
              <.row_action
                event={@on_remove}
                value={%{"nickname" => contact.contact_nickname}}
                label={dgettext("dialogs", "Remove %{nickname}", nickname: contact.contact_nickname)}
                variant="destructive"
                target={@target}
                testid={"contact-remove-#{contact.contact_nickname}"}
              >
                <Icons.icon_btn_remove class="w-4 h-4" />
              </.row_action>
            </.table_cell>
          </.table_row>
        </.table_body>
      </.table>
    </div>
    """
  end

  # ── Add, the one action with no row to belong to ────

  attr :target, :any, default: nil
  attr :on_add, :any, default: nil
  attr :testid_prefix, :string, default: nil

  defp add_button(assigns) do
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
    </div>
    """
  end

  # ── Helpers ────────────────────────────────────────

  @spec format_contact_date(DateTime.t() | nil, String.t() | nil) :: String.t()
  defp format_contact_date(nil, _timezone), do: ""

  defp format_contact_date(dt, timezone) do
    dt
    |> shift_timezone(timezone)
    |> Calendar.strftime("%d/%m/%Y")
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

  # A contact is read as a card, which is why the miniature is one.
  @spec contact_lines([map()]) :: [map()]
  defp contact_lines([]), do: []

  defp contact_lines([contact | _rest]) do
    [
      %{text: contact.contact_nickname, tone: :accent},
      %{text: dgettext("dialogs", "in your address book"), tone: :muted}
    ]
  end
end
