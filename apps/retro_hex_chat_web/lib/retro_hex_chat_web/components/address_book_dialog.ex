defmodule RetroHexChatWeb.Components.AddressBookDialog do
  @moduledoc """
  Address Book tabbed dialog (Ctrl+Shift+A) with four tabs:
  Contacts, Notify, Nick Colors, Control.
  Uses native 98.css tab controls.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :visible, :boolean, default: false
  attr :active_tab, :string, default: "contacts"
  attr :contacts, :list, default: []
  attr :contacts_selected, :string, default: nil
  attr :show_contact_add_dialog, :boolean, default: false
  attr :show_contact_edit_dialog, :boolean, default: false
  attr :notify_entries, :list, default: []
  attr :notify_selected, :string, default: nil
  attr :show_notify_add_dialog, :boolean, default: false
  attr :show_notify_edit_dialog, :boolean, default: false
  attr :auto_whois, :boolean, default: false
  attr :nick_color_entries, :list, default: []
  attr :nick_colors_selected, :string, default: nil
  attr :show_nick_color_add_dialog, :boolean, default: false
  attr :show_nick_color_edit_dialog, :boolean, default: false
  attr :timezone, :string, default: "Etc/UTC"

  @spec address_book_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def address_book_dialog(assigns) do
    selected_note =
      case Enum.find(assigns.contacts, &(&1.contact_nickname == assigns.contacts_selected)) do
        nil -> ""
        entry -> entry.note || ""
      end

    selected_notify_note =
      case Enum.find(assigns.notify_entries, &(&1.tracked_nickname == assigns.notify_selected)) do
        nil -> ""
        entry -> entry.note || ""
      end

    selected_color_index =
      case Enum.find(
             assigns.nick_color_entries,
             &(&1.target_nickname == assigns.nick_colors_selected)
           ) do
        nil -> 0
        entry -> entry.color_index
      end

    assigns =
      assigns
      |> assign(:selected_note, selected_note)
      |> assign(:selected_notify_note, selected_notify_note)
      |> assign(:selected_color_index, selected_color_index)

    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      data-testid="address-book-dialog"
    >
      <div class="window dialog-window--address-book">
        <div class="title-bar">
          <Icons.icon_dialog_address_book class="title-bar-icon" />
          <div class="title-bar-text">Address Book</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="toggle_address_book"></button>
          </div>
        </div>
        <div class="window-body dialog-tabbed-body">
          <menu role="tablist" class="u-mb-0">
            <li
              role="tab"
              aria-selected={@active_tab == "contacts"}
              phx-click="address_book_tab"
              phx-value-tab="contacts"
              data-testid="address-book-tab-contacts"
            >
              <span class="tab-icon">
                <Icons.icon_tab_contacts class="btn-icon__svg" /> Contacts
              </span>
            </li>
            <li
              role="tab"
              aria-selected={@active_tab == "notify"}
              phx-click="address_book_tab"
              phx-value-tab="notify"
              data-testid="address-book-tab-notify"
            >
              <span class="tab-icon">
                <Icons.icon_tab_notify class="btn-icon__svg" /> Notify
              </span>
            </li>
            <li
              role="tab"
              aria-selected={@active_tab == "nick_colors"}
              phx-click="address_book_tab"
              phx-value-tab="nick_colors"
              data-testid="address-book-tab-nick-colors"
            >
              <span class="tab-icon">
                <Icons.icon_tab_colors class="btn-icon__svg" /> Nick Colors
              </span>
            </li>
            <li
              role="tab"
              aria-selected={@active_tab == "control"}
              phx-click="address_book_tab"
              phx-value-tab="control"
              data-testid="address-book-tab-control"
            >
              <span class="tab-icon">
                <Icons.icon_tab_control class="btn-icon__svg" /> Control
              </span>
            </li>
          </menu>
          <div
            role="tabpanel"
            class="window dialog-tab-panel"
          >
            <div :if={@active_tab == "contacts"}>
              <div class="toolbar-row u-items-center u-mb-4">
                <button
                  type="button"
                  phx-click="contact_add_dialog"
                  data-testid="contact-add-btn"
                  class="btn-sm btn-icon"
                >
                  <Icons.icon_btn_add class="btn-icon__svg" /> Add
                </button>
                <button
                  type="button"
                  phx-click="contact_edit_dialog"
                  disabled={is_nil(@contacts_selected)}
                  data-testid="contact-edit-btn"
                  class="btn-sm btn-icon"
                >
                  <Icons.icon_btn_edit class="btn-icon__svg" /> Edit
                </button>
                <button
                  type="button"
                  phx-click="contact_remove"
                  phx-value-nickname={@contacts_selected}
                  disabled={is_nil(@contacts_selected)}
                  data-testid="contact-remove-btn"
                  class="btn-sm btn-icon"
                >
                  <Icons.icon_btn_remove class="btn-icon__svg" /> Remove
                </button>
              </div>
              <div class="sunken-panel u-flex-1 u-overflow-y-auto">
                <table class="table-standard">
                  <thead>
                    <tr class="u-sticky-top">
                      <th>Nickname</th>
                      <th>Notes</th>
                      <th>First Contact</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr
                      :for={entry <- @contacts}
                      phx-click="contact_select"
                      phx-value-nickname={entry.contact_nickname}
                      data-testid={"contact-entry-#{entry.contact_nickname}"}
                      class={[
                        "table-row--selectable",
                        entry.contact_nickname == @contacts_selected && "table-row--selected"
                      ]}
                    >
                      <td>{entry.contact_nickname}</td>
                      <td>{entry.note || ""}</td>
                      <td class="u-text-nowrap">
                        {format_contact_date(entry.first_contact_date, @timezone)}
                      </td>
                    </tr>
                    <tr :if={@contacts == []}>
                      <td colspan="3" class="table-empty">
                        No contacts saved
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div :if={@active_tab == "notify"}>
              <div class="toolbar-row u-items-center u-mb-4">
                <button
                  type="button"
                  phx-click="notify_add_dialog"
                  data-testid="ab-notify-btn-add"
                  class="btn-sm btn-icon"
                >
                  <Icons.icon_btn_add class="btn-icon__svg" /> Add
                </button>
                <button
                  type="button"
                  phx-click="notify_remove"
                  phx-value-nickname={@notify_selected}
                  disabled={is_nil(@notify_selected)}
                  data-testid="ab-notify-btn-remove"
                  class="btn-sm btn-icon"
                >
                  <Icons.icon_btn_remove class="btn-icon__svg" /> Remove
                </button>
                <button
                  type="button"
                  phx-click="notify_edit_dialog"
                  disabled={is_nil(@notify_selected)}
                  data-testid="ab-notify-btn-edit"
                  class="btn-sm btn-icon"
                >
                  <Icons.icon_btn_edit class="btn-icon__svg" /> Edit
                </button>
                <label class="u-text-sm u-ml-auto u-flex u-items-center u-gap-2">
                  <input
                    type="checkbox"
                    checked={@auto_whois}
                    phx-click="toggle_auto_whois"
                    data-testid="ab-notify-auto-whois"
                  /> Auto-Whois
                </label>
              </div>
              <div class="sunken-panel u-flex-1 u-overflow-y-auto">
                <table class="table-standard">
                  <thead>
                    <tr class="u-sticky-top">
                      <th class="notify-status-col"></th>
                      <th>Nickname</th>
                      <th>Notes</th>
                      <th>Last Seen</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr
                      :for={entry <- @notify_entries}
                      phx-click="notify_select"
                      phx-value-nickname={entry.tracked_nickname}
                      data-testid={"ab-notify-entry-#{entry.tracked_nickname}"}
                      class={[
                        "table-row--selectable",
                        entry.tracked_nickname == @notify_selected && "table-row--selected"
                      ]}
                    >
                      <td class="u-text-center">
                        {status_dot(entry.online)}
                      </td>
                      <td>{entry.tracked_nickname}</td>
                      <td>{entry.note || ""}</td>
                      <td class="u-text-nowrap">
                        {format_last_seen(entry.last_seen_at, @timezone)}
                      </td>
                    </tr>
                    <tr :if={@notify_entries == []}>
                      <td colspan="4" class="table-empty">
                        No entries. Click Add to track a nickname.
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div :if={@active_tab == "nick_colors"}>
              <div class="toolbar-row u-items-center u-mb-4">
                <button
                  type="button"
                  phx-click="nick_color_add_dialog"
                  data-testid="nick-color-add-btn"
                  class="btn-sm btn-icon"
                >
                  <Icons.icon_btn_add class="btn-icon__svg" /> Add
                </button>
                <button
                  type="button"
                  phx-click="nick_color_edit_dialog"
                  disabled={is_nil(@nick_colors_selected)}
                  data-testid="nick-color-edit-btn"
                  class="btn-sm btn-icon"
                >
                  <Icons.icon_btn_edit class="btn-icon__svg" /> Edit
                </button>
                <button
                  type="button"
                  phx-click="nick_color_remove"
                  phx-value-nickname={@nick_colors_selected}
                  disabled={is_nil(@nick_colors_selected)}
                  data-testid="nick-color-remove-btn"
                  class="btn-sm btn-icon"
                >
                  <Icons.icon_btn_remove class="btn-icon__svg" /> Remove
                </button>
              </div>
              <div class="sunken-panel u-flex-1 u-overflow-y-auto">
                <table class="table-standard">
                  <thead>
                    <tr class="u-sticky-top">
                      <th>Nickname</th>
                      <th>Color</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr
                      :for={entry <- @nick_color_entries}
                      phx-click="nick_color_select"
                      phx-value-nickname={entry.target_nickname}
                      data-testid={"nick-color-entry-#{entry.target_nickname}"}
                      class={[
                        "table-row--selectable",
                        entry.target_nickname == @nick_colors_selected && "table-row--selected"
                      ]}
                    >
                      <td>{entry.target_nickname}</td>
                      <td>
                        <span
                          class="highlight-color-swatch"
                          style={"background: #{color_hex(entry.color_index)}; vertical-align: middle;"}
                          title={color_name(entry.color_index)}
                        >
                        </span>
                        {color_name(entry.color_index)}
                      </td>
                    </tr>
                    <tr :if={@nick_color_entries == []}>
                      <td colspan="2" class="table-empty">
                        No custom colors set. Nicknames use automatic colors.
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div :if={@active_tab == "control"}>
              <p class="u-text-muted u-text-center address-book-placeholder">
                Ignore management will be available in a future update.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    <%!-- Contact Add Dialog --%>
    <div
      :if={@show_contact_add_dialog}
      class="dialog-overlay dialog-overlay--above"
    >
      <div class="window dialog-window--narrow">
        <div class="title-bar">
          <Icons.icon_dialog_address_book class="title-bar-icon" />
          <div class="title-bar-text">Add Contact</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="contact_add_cancel"></button>
          </div>
        </div>
        <div class="window-body dialog-body">
          <form phx-submit="contact_add" data-testid="contact-add-form">
            <div class="u-mb-8">
              <label
                for="contact-add-nickname"
                class="form-label"
              >
                Nickname:
              </label>
              <input
                type="text"
                id="contact-add-nickname"
                name="nickname"
                required
                maxlength="16"
                autocomplete="off"
                class="u-w-full"
                data-testid="contact-add-nickname"
              />
            </div>
            <div class="u-mb-12">
              <label
                for="contact-add-note"
                class="form-label"
              >
                Notes:
              </label>
              <textarea
                id="contact-add-note"
                name="note"
                maxlength="200"
                autocomplete="off"
                rows="3"
                class="textarea-resizable"
                data-testid="contact-add-note"
              />
            </div>
            <div class="dialog-buttons dialog-buttons--gap-8">
              <button type="submit" class="btn-icon" data-testid="contact-add-ok">
                <Icons.icon_btn_ok class="btn-icon__svg" /> OK
              </button>
              <button
                type="button"
                class="btn-icon"
                phx-click="contact_add_cancel"
                data-testid="contact-add-cancel"
              >
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <%!-- Notify Add Dialog --%>
    <div
      :if={@show_notify_add_dialog}
      class="dialog-overlay dialog-overlay--above"
    >
      <div class="window dialog-window--narrow">
        <div class="title-bar">
          <Icons.icon_dialog_address_book class="title-bar-icon" />
          <div class="title-bar-text">Add to Notify List</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="notify_add_cancel"></button>
          </div>
        </div>
        <div class="window-body dialog-body">
          <form phx-submit="notify_add" data-testid="ab-notify-add-form">
            <div class="u-mb-8">
              <label class="form-label">Nickname:</label>
              <input
                type="text"
                name="nickname"
                required
                maxlength="16"
                autocomplete="off"
                class="u-w-full"
                data-testid="ab-notify-add-nickname"
              />
            </div>
            <div class="u-mb-12">
              <label class="form-label">Notes:</label>
              <input
                type="text"
                name="note"
                maxlength="200"
                autocomplete="off"
                class="u-w-full"
                data-testid="ab-notify-add-note"
              />
            </div>
            <div class="dialog-buttons dialog-buttons--gap-8">
              <button type="submit" class="btn-icon" data-testid="ab-notify-add-ok">
                <Icons.icon_btn_ok class="btn-icon__svg" /> OK
              </button>
              <button
                type="button"
                class="btn-icon"
                phx-click="notify_add_cancel"
                data-testid="ab-notify-add-cancel"
              >
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <%!-- Notify Edit Dialog --%>
    <div
      :if={@show_notify_edit_dialog}
      class="dialog-overlay dialog-overlay--above"
    >
      <div class="window dialog-window--narrow">
        <div class="title-bar">
          <Icons.icon_dialog_address_book class="title-bar-icon" />
          <div class="title-bar-text">Edit Notify Entry</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="notify_edit_cancel"></button>
          </div>
        </div>
        <div class="window-body dialog-body">
          <form phx-submit="notify_edit" data-testid="ab-notify-edit-form">
            <div class="u-mb-8">
              <label class="form-label">Nickname:</label>
              <input
                type="text"
                name="nickname"
                value={@notify_selected}
                readonly
                class="input-readonly"
              />
            </div>
            <div class="u-mb-12">
              <label class="form-label">Notes:</label>
              <input
                type="text"
                name="note"
                value={@selected_notify_note}
                maxlength="200"
                autocomplete="off"
                class="u-w-full"
                data-testid="ab-notify-edit-note"
              />
            </div>
            <div class="dialog-buttons dialog-buttons--gap-8">
              <button type="submit" class="btn-icon" data-testid="ab-notify-edit-ok">
                <Icons.icon_btn_ok class="btn-icon__svg" /> OK
              </button>
              <button
                type="button"
                class="btn-icon"
                phx-click="notify_edit_cancel"
                data-testid="ab-notify-edit-cancel"
              >
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <%!-- Nick Color Add Dialog --%>
    <div
      :if={@show_nick_color_add_dialog}
      class="dialog-overlay dialog-overlay--above"
    >
      <div class="window dialog-window--narrow">
        <div class="title-bar">
          <Icons.icon_dialog_address_book class="title-bar-icon" />
          <div class="title-bar-text">Add Nick Color</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="nick_color_add_cancel"></button>
          </div>
        </div>
        <div class="window-body dialog-body">
          <form phx-submit="nick_color_add" data-testid="nick-color-add-form">
            <div class="u-mb-8">
              <label class="form-label">Nickname:</label>
              <input
                type="text"
                name="nickname"
                required
                maxlength="16"
                autocomplete="off"
                class="u-w-full"
                data-testid="nick-color-add-nickname"
              />
            </div>
            <div class="u-mb-12">
              <label class="form-label u-mb-4">Color:</label>
              {color_picker_grid(assigns, "nick-color-add")}
            </div>
            <div class="dialog-buttons dialog-buttons--gap-8">
              <button type="submit" class="btn-icon" data-testid="nick-color-add-ok">
                <Icons.icon_btn_ok class="btn-icon__svg" /> OK
              </button>
              <button
                type="button"
                class="btn-icon"
                phx-click="nick_color_add_cancel"
                data-testid="nick-color-add-cancel"
              >
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <%!-- Nick Color Edit Dialog --%>
    <div
      :if={@show_nick_color_edit_dialog}
      class="dialog-overlay dialog-overlay--above"
    >
      <div class="window dialog-window--narrow">
        <div class="title-bar">
          <Icons.icon_dialog_address_book class="title-bar-icon" />
          <div class="title-bar-text">Edit Nick Color</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="nick_color_edit_cancel"></button>
          </div>
        </div>
        <div class="window-body dialog-body">
          <form phx-submit="nick_color_edit" data-testid="nick-color-edit-form">
            <div class="u-mb-8">
              <label class="form-label">Nickname:</label>
              <input
                type="text"
                name="nickname"
                value={@nick_colors_selected}
                readonly
                class="input-readonly"
              />
            </div>
            <div class="u-mb-12">
              <label class="form-label u-mb-4">Color:</label>
              {color_picker_grid(assigns, "nick-color-edit")}
            </div>
            <div class="dialog-buttons dialog-buttons--gap-8">
              <button type="submit" class="btn-icon" data-testid="nick-color-edit-ok">
                <Icons.icon_btn_ok class="btn-icon__svg" /> OK
              </button>
              <button
                type="button"
                class="btn-icon"
                phx-click="nick_color_edit_cancel"
                data-testid="nick-color-edit-cancel"
              >
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <%!-- Contact Edit Dialog --%>
    <div
      :if={@show_contact_edit_dialog}
      class="dialog-overlay dialog-overlay--above"
    >
      <div class="window dialog-window--narrow">
        <div class="title-bar">
          <Icons.icon_dialog_address_book class="title-bar-icon" />
          <div class="title-bar-text">Edit Contact</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="contact_edit_cancel"></button>
          </div>
        </div>
        <div class="window-body dialog-body">
          <form phx-submit="contact_edit" data-testid="contact-edit-form">
            <div class="u-mb-8">
              <label
                for="contact-edit-nickname"
                class="form-label"
              >
                Nickname:
              </label>
              <input
                type="text"
                id="contact-edit-nickname"
                name="nickname"
                value={@contacts_selected}
                readonly
                class="input-readonly"
                data-testid="contact-edit-nickname"
              />
            </div>
            <div class="u-mb-12">
              <label
                for="contact-edit-note"
                class="form-label"
              >
                Notes:
              </label>
              <textarea
                id="contact-edit-note"
                name="note"
                maxlength="200"
                autocomplete="off"
                rows="3"
                class="textarea-resizable"
                data-testid="contact-edit-note"
              >{@selected_note}</textarea>
            </div>
            <div class="dialog-buttons dialog-buttons--gap-8">
              <button type="submit" class="btn-icon" data-testid="contact-edit-ok">
                <Icons.icon_btn_ok class="btn-icon__svg" /> OK
              </button>
              <button
                type="button"
                class="btn-icon"
                phx-click="contact_edit_cancel"
                data-testid="contact-edit-cancel"
              >
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  @spec format_contact_date(DateTime.t() | nil, String.t()) :: String.t()
  defp format_contact_date(nil, _tz), do: ""

  defp format_contact_date(%DateTime{} = dt, tz),
    do: dt |> RetroHexChatWeb.Timezone.shift(tz) |> Calendar.strftime("%Y-%m-%d")

  @spec status_dot(boolean()) :: Phoenix.LiveView.Rendered.t()
  defp status_dot(true) do
    assigns = %{}

    ~H"""
    <span class="u-status-dot u-status-dot--online" title="Online"></span>
    """
  end

  defp status_dot(false) do
    assigns = %{}

    ~H"""
    <span class="u-status-dot u-status-dot--offline" title="Offline"></span>
    """
  end

  @spec format_last_seen(DateTime.t() | nil, String.t()) :: String.t()
  defp format_last_seen(nil, _tz), do: "Never"

  defp format_last_seen(%DateTime{} = dt, tz),
    do: dt |> RetroHexChatWeb.Timezone.shift(tz) |> Calendar.strftime("%Y-%m-%d %H:%M")

  @irc_colors %{
    0 => {"White", "#ffffff"},
    1 => {"Black", "#000000"},
    2 => {"Navy", "#00007f"},
    3 => {"Green", "#009300"},
    4 => {"Red", "#ff0000"},
    5 => {"Maroon", "#7f0000"},
    6 => {"Purple", "#9c009c"},
    7 => {"Orange", "#fc7f00"},
    8 => {"Yellow", "#ffff00"},
    9 => {"Lime", "#00fc00"},
    10 => {"Teal", "#009393"},
    11 => {"Cyan", "#00ffff"},
    12 => {"Blue", "#0000fc"},
    13 => {"Magenta", "#ff00ff"},
    14 => {"Grey", "#7f7f7f"},
    15 => {"Silver", "#d2d2d2"}
  }

  @spec color_hex(non_neg_integer()) :: String.t()
  defp color_hex(index) do
    case Map.get(@irc_colors, index) do
      {_name, hex} -> hex
      nil -> "#808080"
    end
  end

  @spec color_name(non_neg_integer()) :: String.t()
  defp color_name(index) do
    case Map.get(@irc_colors, index) do
      {name, _hex} -> name
      nil -> "Unknown"
    end
  end

  @spec color_picker_grid(map(), String.t()) :: Phoenix.LiveView.Rendered.t()
  defp color_picker_grid(assigns, prefix) do
    colors =
      for i <- 0..15, do: {i, elem(Map.get(@irc_colors, i), 0), elem(Map.get(@irc_colors, i), 1)}

    assigns = assign(assigns, :colors, colors) |> assign(:prefix, prefix)

    ~H"""
    <div
      class="ab-color-grid"
      data-testid={"#{@prefix}-color-grid"}
    >
      <label
        :for={{idx, name, hex} <- @colors}
        class="ab-color-label"
        title={name}
      >
        <input
          type="radio"
          name="color_index"
          value={idx}
          checked={idx == @selected_color_index}
          class="u-hidden"
        />
        <span
          class="ab-color-swatch"
          data-testid={"#{@prefix}-swatch-#{idx}"}
          style={"border: #{if idx == @selected_color_index, do: "2px solid #000080", else: "1px solid #808080"}; background: #{hex};"}
        >
        </span>
      </label>
    </div>
    """
  end
end
