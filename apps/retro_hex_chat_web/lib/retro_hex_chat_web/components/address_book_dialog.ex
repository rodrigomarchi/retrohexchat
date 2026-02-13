defmodule RetroHexChatWeb.Components.AddressBookDialog do
  @moduledoc """
  Address Book tabbed dialog (Ctrl+Shift+A) with four tabs:
  Contacts, Notify, Nick Colors, Control.
  Uses native 98.css tab controls.
  """
  use Phoenix.Component

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
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.3);"
    >
      <div class="window" style="width: 480px; height: 400px; display: flex; flex-direction: column;">
        <div class="title-bar">
          <div class="title-bar-text">Address Book</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="toggle_address_book"></button>
          </div>
        </div>
        <div
          class="window-body"
          style="padding: 8px; display: flex; flex-direction: column; flex: 1; overflow: hidden;"
        >
          <menu role="tablist" style="margin-bottom: 0;">
            <li
              role="tab"
              aria-selected={@active_tab == "contacts"}
              phx-click="address_book_tab"
              phx-value-tab="contacts"
              data-testid="address-book-tab-contacts"
            >
              Contacts
            </li>
            <li
              role="tab"
              aria-selected={@active_tab == "notify"}
              phx-click="address_book_tab"
              phx-value-tab="notify"
              data-testid="address-book-tab-notify"
            >
              Notify
            </li>
            <li
              role="tab"
              aria-selected={@active_tab == "nick_colors"}
              phx-click="address_book_tab"
              phx-value-tab="nick_colors"
              data-testid="address-book-tab-nick-colors"
            >
              Nick Colors
            </li>
            <li
              role="tab"
              aria-selected={@active_tab == "control"}
              phx-click="address_book_tab"
              phx-value-tab="control"
              data-testid="address-book-tab-control"
            >
              Control
            </li>
          </menu>
          <div
            role="tabpanel"
            class="window"
            style="flex: 1; overflow-y: auto; padding: 8px; margin-top: -2px;"
          >
            <div :if={@active_tab == "contacts"}>
              <div style="display: flex; gap: 4px; margin-bottom: 4px; align-items: center;">
                <button
                  type="button"
                  phx-click="contact_add_dialog"
                  data-testid="contact-add-btn"
                  style="font-size: 11px; padding: 1px 8px;"
                >
                  Add
                </button>
                <button
                  type="button"
                  phx-click="contact_edit_dialog"
                  disabled={is_nil(@contacts_selected)}
                  data-testid="contact-edit-btn"
                  style="font-size: 11px; padding: 1px 8px;"
                >
                  Edit
                </button>
                <button
                  type="button"
                  phx-click="contact_remove"
                  phx-value-nickname={@contacts_selected}
                  disabled={is_nil(@contacts_selected)}
                  data-testid="contact-remove-btn"
                  style="font-size: 11px; padding: 1px 8px;"
                >
                  Remove
                </button>
              </div>
              <div class="sunken-panel" style="flex: 1; overflow-y: auto;">
                <table style="width: 100%; border-collapse: collapse; font-size: 11px;">
                  <thead>
                    <tr style="background: #c0c0c0; position: sticky; top: 0;">
                      <th style="text-align: left; padding: 2px 4px;">Nickname</th>
                      <th style="text-align: left; padding: 2px 4px;">Notes</th>
                      <th style="text-align: left; padding: 2px 4px;">First Contact</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr
                      :for={entry <- @contacts}
                      phx-click="contact_select"
                      phx-value-nickname={entry.contact_nickname}
                      data-testid={"contact-entry-#{entry.contact_nickname}"}
                      style={contact_row_style(entry.contact_nickname, @contacts_selected)}
                    >
                      <td style="padding: 2px 4px;">{entry.contact_nickname}</td>
                      <td style="padding: 2px 4px;">{entry.note || ""}</td>
                      <td style="padding: 2px 4px; white-space: nowrap;">
                        {format_contact_date(entry.first_contact_date)}
                      </td>
                    </tr>
                    <tr :if={@contacts == []}>
                      <td
                        colspan="3"
                        style="text-align: center; padding: 8px; color: #808080; font-size: 11px;"
                      >
                        No contacts saved
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div :if={@active_tab == "notify"}>
              <div style="display: flex; gap: 4px; margin-bottom: 4px; align-items: center;">
                <button
                  type="button"
                  phx-click="notify_add_dialog"
                  data-testid="ab-notify-btn-add"
                  style="font-size: 11px; padding: 1px 8px;"
                >
                  Add
                </button>
                <button
                  type="button"
                  phx-click="notify_remove"
                  phx-value-nickname={@notify_selected}
                  disabled={is_nil(@notify_selected)}
                  data-testid="ab-notify-btn-remove"
                  style="font-size: 11px; padding: 1px 8px;"
                >
                  Remove
                </button>
                <button
                  type="button"
                  phx-click="notify_edit_dialog"
                  disabled={is_nil(@notify_selected)}
                  data-testid="ab-notify-btn-edit"
                  style="font-size: 11px; padding: 1px 8px;"
                >
                  Edit
                </button>
                <label style="font-size: 11px; margin-left: auto; display: flex; align-items: center; gap: 2px;">
                  <input
                    type="checkbox"
                    checked={@auto_whois}
                    phx-click="toggle_auto_whois"
                    data-testid="ab-notify-auto-whois"
                  /> Auto-Whois
                </label>
              </div>
              <div class="sunken-panel" style="flex: 1; overflow-y: auto;">
                <table style="width: 100%; border-collapse: collapse; font-size: 11px;">
                  <thead>
                    <tr style="background: #c0c0c0; position: sticky; top: 0;">
                      <th style="text-align: left; padding: 2px 4px; width: 24px;"></th>
                      <th style="text-align: left; padding: 2px 4px;">Nickname</th>
                      <th style="text-align: left; padding: 2px 4px;">Notes</th>
                      <th style="text-align: left; padding: 2px 4px;">Last Seen</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr
                      :for={entry <- @notify_entries}
                      phx-click="notify_select"
                      phx-value-nickname={entry.tracked_nickname}
                      data-testid={"ab-notify-entry-#{entry.tracked_nickname}"}
                      style={notify_row_style(entry.tracked_nickname, @notify_selected)}
                    >
                      <td style="text-align: center; padding: 2px 4px;">
                        {status_dot(entry.online)}
                      </td>
                      <td style="padding: 2px 4px;">{entry.tracked_nickname}</td>
                      <td style="padding: 2px 4px;">{entry.note || ""}</td>
                      <td style="padding: 2px 4px; white-space: nowrap;">
                        {format_last_seen(entry.last_seen_at)}
                      </td>
                    </tr>
                    <tr :if={@notify_entries == []}>
                      <td
                        colspan="4"
                        style="text-align: center; padding: 8px; color: #808080; font-size: 11px;"
                      >
                        No entries. Click Add to track a nickname.
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div :if={@active_tab == "nick_colors"}>
              <div style="display: flex; gap: 4px; margin-bottom: 4px; align-items: center;">
                <button
                  type="button"
                  phx-click="nick_color_add_dialog"
                  data-testid="nick-color-add-btn"
                  style="font-size: 11px; padding: 1px 8px;"
                >
                  Add
                </button>
                <button
                  type="button"
                  phx-click="nick_color_edit_dialog"
                  disabled={is_nil(@nick_colors_selected)}
                  data-testid="nick-color-edit-btn"
                  style="font-size: 11px; padding: 1px 8px;"
                >
                  Edit
                </button>
                <button
                  type="button"
                  phx-click="nick_color_remove"
                  phx-value-nickname={@nick_colors_selected}
                  disabled={is_nil(@nick_colors_selected)}
                  data-testid="nick-color-remove-btn"
                  style="font-size: 11px; padding: 1px 8px;"
                >
                  Remove
                </button>
              </div>
              <div class="sunken-panel" style="flex: 1; overflow-y: auto;">
                <table style="width: 100%; border-collapse: collapse; font-size: 11px;">
                  <thead>
                    <tr style="background: #c0c0c0; position: sticky; top: 0;">
                      <th style="text-align: left; padding: 2px 4px;">Nickname</th>
                      <th style="text-align: left; padding: 2px 4px;">Color</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr
                      :for={entry <- @nick_color_entries}
                      phx-click="nick_color_select"
                      phx-value-nickname={entry.target_nickname}
                      data-testid={"nick-color-entry-#{entry.target_nickname}"}
                      style={nick_color_row_style(entry.target_nickname, @nick_colors_selected)}
                    >
                      <td style="padding: 2px 4px;">{entry.target_nickname}</td>
                      <td style="padding: 2px 4px;">
                        <span
                          style={"display: inline-block; width: 16px; height: 16px; border: 1px solid #808080; vertical-align: middle; background: #{color_hex(entry.color_index)};"}
                          title={color_name(entry.color_index)}
                        >
                        </span>
                        <span style="margin-left: 4px;">{color_name(entry.color_index)}</span>
                      </td>
                    </tr>
                    <tr :if={@nick_color_entries == []}>
                      <td
                        colspan="2"
                        style="text-align: center; padding: 8px; color: #808080; font-size: 11px;"
                      >
                        No custom colors set. Nicknames use automatic colors.
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
            <div :if={@active_tab == "control"}>
              <p style="color: #808080; text-align: center; margin-top: 40px;">
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
      class="dialog-overlay"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.5);"
    >
      <div class="window" style="min-width: 280px; max-width: 340px;">
        <div class="title-bar">
          <div class="title-bar-text">Add Contact</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="contact_add_cancel"></button>
          </div>
        </div>
        <div class="window-body" style="padding: 12px;">
          <form phx-submit="contact_add" data-testid="contact-add-form">
            <div style="margin-bottom: 8px;">
              <label
                for="contact-add-nickname"
                style="font-size: 11px; display: block; margin-bottom: 2px;"
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
                style="width: 100%;"
                data-testid="contact-add-nickname"
              />
            </div>
            <div style="margin-bottom: 12px;">
              <label
                for="contact-add-note"
                style="font-size: 11px; display: block; margin-bottom: 2px;"
              >
                Notes:
              </label>
              <textarea
                id="contact-add-note"
                name="note"
                maxlength="200"
                autocomplete="off"
                rows="3"
                style="width: 100%; resize: vertical;"
                data-testid="contact-add-note"
              />
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 8px;">
              <button type="submit" data-testid="contact-add-ok">OK</button>
              <button type="button" phx-click="contact_add_cancel" data-testid="contact-add-cancel">
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <%!-- Notify Add Dialog --%>
    <div
      :if={@show_notify_add_dialog}
      class="dialog-overlay"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.5);"
    >
      <div class="window" style="min-width: 280px; max-width: 340px;">
        <div class="title-bar">
          <div class="title-bar-text">Add to Notify List</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="notify_add_cancel"></button>
          </div>
        </div>
        <div class="window-body" style="padding: 12px;">
          <form phx-submit="notify_add" data-testid="ab-notify-add-form">
            <div style="margin-bottom: 8px;">
              <label style="font-size: 11px; display: block; margin-bottom: 2px;">Nickname:</label>
              <input
                type="text"
                name="nickname"
                required
                maxlength="16"
                autocomplete="off"
                style="width: 100%;"
                data-testid="ab-notify-add-nickname"
              />
            </div>
            <div style="margin-bottom: 12px;">
              <label style="font-size: 11px; display: block; margin-bottom: 2px;">Notes:</label>
              <input
                type="text"
                name="note"
                maxlength="200"
                autocomplete="off"
                style="width: 100%;"
                data-testid="ab-notify-add-note"
              />
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 8px;">
              <button type="submit" data-testid="ab-notify-add-ok">OK</button>
              <button type="button" phx-click="notify_add_cancel" data-testid="ab-notify-add-cancel">
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <%!-- Notify Edit Dialog --%>
    <div
      :if={@show_notify_edit_dialog}
      class="dialog-overlay"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.5);"
    >
      <div class="window" style="min-width: 280px; max-width: 340px;">
        <div class="title-bar">
          <div class="title-bar-text">Edit Notify Entry</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="notify_edit_cancel"></button>
          </div>
        </div>
        <div class="window-body" style="padding: 12px;">
          <form phx-submit="notify_edit" data-testid="ab-notify-edit-form">
            <div style="margin-bottom: 8px;">
              <label style="font-size: 11px; display: block; margin-bottom: 2px;">Nickname:</label>
              <input
                type="text"
                name="nickname"
                value={@notify_selected}
                readonly
                style="width: 100%; background: #c0c0c0;"
              />
            </div>
            <div style="margin-bottom: 12px;">
              <label style="font-size: 11px; display: block; margin-bottom: 2px;">Notes:</label>
              <input
                type="text"
                name="note"
                value={@selected_notify_note}
                maxlength="200"
                autocomplete="off"
                style="width: 100%;"
                data-testid="ab-notify-edit-note"
              />
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 8px;">
              <button type="submit" data-testid="ab-notify-edit-ok">OK</button>
              <button type="button" phx-click="notify_edit_cancel" data-testid="ab-notify-edit-cancel">
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <%!-- Nick Color Add Dialog --%>
    <div
      :if={@show_nick_color_add_dialog}
      class="dialog-overlay"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.5);"
    >
      <div class="window" style="min-width: 280px; max-width: 340px;">
        <div class="title-bar">
          <div class="title-bar-text">Add Nick Color</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="nick_color_add_cancel"></button>
          </div>
        </div>
        <div class="window-body" style="padding: 12px;">
          <form phx-submit="nick_color_add" data-testid="nick-color-add-form">
            <div style="margin-bottom: 8px;">
              <label style="font-size: 11px; display: block; margin-bottom: 2px;">Nickname:</label>
              <input
                type="text"
                name="nickname"
                required
                maxlength="16"
                autocomplete="off"
                style="width: 100%;"
                data-testid="nick-color-add-nickname"
              />
            </div>
            <div style="margin-bottom: 12px;">
              <label style="font-size: 11px; display: block; margin-bottom: 4px;">Color:</label>
              {color_picker_grid(assigns, "nick-color-add")}
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 8px;">
              <button type="submit" data-testid="nick-color-add-ok">OK</button>
              <button
                type="button"
                phx-click="nick_color_add_cancel"
                data-testid="nick-color-add-cancel"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <%!-- Nick Color Edit Dialog --%>
    <div
      :if={@show_nick_color_edit_dialog}
      class="dialog-overlay"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.5);"
    >
      <div class="window" style="min-width: 280px; max-width: 340px;">
        <div class="title-bar">
          <div class="title-bar-text">Edit Nick Color</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="nick_color_edit_cancel"></button>
          </div>
        </div>
        <div class="window-body" style="padding: 12px;">
          <form phx-submit="nick_color_edit" data-testid="nick-color-edit-form">
            <div style="margin-bottom: 8px;">
              <label style="font-size: 11px; display: block; margin-bottom: 2px;">Nickname:</label>
              <input
                type="text"
                name="nickname"
                value={@nick_colors_selected}
                readonly
                style="width: 100%; background: #c0c0c0;"
              />
            </div>
            <div style="margin-bottom: 12px;">
              <label style="font-size: 11px; display: block; margin-bottom: 4px;">Color:</label>
              {color_picker_grid(assigns, "nick-color-edit")}
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 8px;">
              <button type="submit" data-testid="nick-color-edit-ok">OK</button>
              <button
                type="button"
                phx-click="nick_color_edit_cancel"
                data-testid="nick-color-edit-cancel"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <%!-- Contact Edit Dialog --%>
    <div
      :if={@show_contact_edit_dialog}
      class="dialog-overlay"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.5);"
    >
      <div class="window" style="min-width: 280px; max-width: 340px;">
        <div class="title-bar">
          <div class="title-bar-text">Edit Contact</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="contact_edit_cancel"></button>
          </div>
        </div>
        <div class="window-body" style="padding: 12px;">
          <form phx-submit="contact_edit" data-testid="contact-edit-form">
            <div style="margin-bottom: 8px;">
              <label
                for="contact-edit-nickname"
                style="font-size: 11px; display: block; margin-bottom: 2px;"
              >
                Nickname:
              </label>
              <input
                type="text"
                id="contact-edit-nickname"
                name="nickname"
                value={@contacts_selected}
                readonly
                style="width: 100%; background: #c0c0c0;"
                data-testid="contact-edit-nickname"
              />
            </div>
            <div style="margin-bottom: 12px;">
              <label
                for="contact-edit-note"
                style="font-size: 11px; display: block; margin-bottom: 2px;"
              >
                Notes:
              </label>
              <textarea
                id="contact-edit-note"
                name="note"
                maxlength="200"
                autocomplete="off"
                rows="3"
                style="width: 100%; resize: vertical;"
                data-testid="contact-edit-note"
              >{@selected_note}</textarea>
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 8px;">
              <button type="submit" data-testid="contact-edit-ok">OK</button>
              <button
                type="button"
                phx-click="contact_edit_cancel"
                data-testid="contact-edit-cancel"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  @spec contact_row_style(String.t(), String.t() | nil) :: String.t()
  defp contact_row_style(nickname, selected) when nickname == selected do
    "background: #000080; color: #ffffff; cursor: pointer;"
  end

  defp contact_row_style(_nickname, _selected) do
    "cursor: pointer;"
  end

  @spec format_contact_date(DateTime.t() | nil) :: String.t()
  defp format_contact_date(nil), do: ""
  defp format_contact_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")

  @spec notify_row_style(String.t(), String.t() | nil) :: String.t()
  defp notify_row_style(nickname, selected) when nickname == selected do
    "background: #000080; color: #ffffff; cursor: pointer;"
  end

  defp notify_row_style(_nickname, _selected), do: "cursor: pointer;"

  @spec status_dot(boolean()) :: Phoenix.LiveView.Rendered.t()
  defp status_dot(true) do
    assigns = %{}

    ~H"""
    <span
      style="display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: #00a000;"
      title="Online"
    >
    </span>
    """
  end

  defp status_dot(false) do
    assigns = %{}

    ~H"""
    <span
      style="display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: #808080;"
      title="Offline"
    >
    </span>
    """
  end

  @spec format_last_seen(DateTime.t() | nil) :: String.t()
  defp format_last_seen(nil), do: "Never"
  defp format_last_seen(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  @spec nick_color_row_style(String.t(), String.t() | nil) :: String.t()
  defp nick_color_row_style(nickname, selected) when nickname == selected do
    "background: #000080; color: #ffffff; cursor: pointer;"
  end

  defp nick_color_row_style(_nickname, _selected), do: "cursor: pointer;"

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
      style="display: grid; grid-template-columns: repeat(8, 1fr); gap: 2px;"
      data-testid={"#{@prefix}-color-grid"}
    >
      <label
        :for={{idx, name, hex} <- @colors}
        style="display: flex; align-items: center; justify-content: center;"
        title={name}
      >
        <input
          type="radio"
          name="color_index"
          value={idx}
          checked={idx == @selected_color_index}
          style="display: none;"
        />
        <span
          data-testid={"#{@prefix}-swatch-#{idx}"}
          style={"display: inline-block; width: 20px; height: 20px; border: #{if idx == @selected_color_index, do: "2px solid #000080", else: "1px solid #808080"}; cursor: pointer; background: #{hex};"}
        >
        </span>
      </label>
    </div>
    """
  end
end
