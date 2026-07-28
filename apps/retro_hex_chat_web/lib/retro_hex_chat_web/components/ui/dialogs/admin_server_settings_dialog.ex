defmodule RetroHexChatWeb.Components.UI.AdminServerSettingsDialog do
  @moduledoc """
  Admin Server Settings window — the server's own configuration.

  The form edits the settings record; the two read-only panes below show what
  the server currently reports, so a save can be checked against reality
  without leaving the window.

  Saving dispatches one command per changed field, which is why the outcome
  strip can report several lines at once.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AdminShared
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :target, :any, default: nil
  attr :info, :string, default: nil
  attr :settings_text, :string, default: nil
  attr :settings_table, :any, default: nil, doc: "%Admin.Table{} for the settings"
  attr :values, :map, default: %{}
  attr :result, :any, default: nil
  attr :can_edit, :boolean, default: false
  attr :on_save, :any, default: nil
  attr :on_refresh, :any, default: nil
  attr :on_cancel, :any, default: nil

  @doc "Framed variant with dialog chrome — used by the showcase page."
  @spec admin_server_settings_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_server_settings_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="max-w-3xl">
      <.dialog_header id={@id} title={dgettext("dialogs", "Server Settings")} on_close={@on_cancel}>
        <:icon><Icons.icon_server class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <.admin_server_settings_panel {assigns} />
      </.dialog_body>
    </.dialog>
    """
  end

  attr :id, :string, required: true
  attr :target, :any, default: nil
  attr :info, :string, default: nil
  attr :settings_text, :string, default: nil
  attr :settings_table, :any, default: nil, doc: "%Admin.Table{} for the settings"
  attr :values, :map, default: %{}
  attr :result, :any, default: nil
  attr :can_edit, :boolean, default: false
  attr :on_save, :any, default: nil
  attr :on_refresh, :any, default: nil

  @spec admin_server_settings_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_server_settings_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-content"}
      data-testid="admin-server-settings-panel"
      class="adm-dialog flex h-full min-h-0 flex-col gap-retro-8"
    >
      <div class="adm-scroll min-h-0 flex-1 overflow-y-auto">
        <div class="space-y-retro-8">
          <form
            id="admin-server-settings-form"
            phx-submit={@on_save}
            phx-target={@target}
            class="space-y-retro-8"
          >
            <div class="grid gap-retro-6 md:grid-cols-2">
              <.setting_field
                id="admin-server-settings-name"
                name="server_name"
                label={dgettext("dialogs", "Server name")}
                value={setting_value(@values, "server_name")}
                disabled={not @can_edit}
              />
              <.setting_field
                id="admin-server-settings-max-channels"
                name="max_channels"
                label={dgettext("dialogs", "Max channels")}
                value={setting_value(@values, "max_channels")}
                disabled={not @can_edit}
                type="number"
                min="1"
              />
              <.setting_field
                id="admin-server-settings-description"
                name="server_description"
                label={dgettext("dialogs", "Description")}
                value={setting_value(@values, "server_description")}
                disabled={not @can_edit}
                type="textarea"
                rows={3}
              />
              <.setting_field
                id="admin-server-settings-welcome"
                name="welcome_message"
                label={dgettext("dialogs", "Welcome message")}
                value={setting_value(@values, "welcome_message")}
                disabled={not @can_edit}
                type="textarea"
                rows={3}
              />
              <div>
                <label
                  for="admin-server-settings-registration"
                  class="block text-xs font-bold mb-retro-2"
                >
                  {dgettext("dialogs", "Registration")}
                </label>
                <select
                  id="admin-server-settings-registration"
                  name="registration"
                  class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
                  disabled={not @can_edit}
                >
                  <option value="open" selected={setting_value(@values, "registration") == "open"}>
                    {dgettext("dialogs", "open")}
                  </option>
                  <option
                    value="closed"
                    selected={setting_value(@values, "registration") == "closed"}
                  >
                    {dgettext("dialogs", "closed")}
                  </option>
                </select>
              </div>
              <.setting_field
                id="admin-server-settings-whowas-retention"
                name="whowas_retention_seconds"
                label={dgettext("dialogs", "Whowas retention")}
                value={setting_value(@values, "whowas_retention_seconds")}
                disabled={not @can_edit}
                type="number"
                min="1"
                max="86400"
              />
            </div>

            <div class="flex flex-wrap justify-end gap-retro-4">
              <.button
                type="button"
                size="sm"
                variant="outline"
                phx-click={@on_refresh}
                phx-target={@target}
                disabled={not @can_edit}
              >
                <:icon><Icons.icon_btn_refresh class="w-[14px] h-[14px]" /></:icon>
                {dgettext("dialogs", "Refresh")}
              </.button>
              <.button type="submit" size="sm" disabled={not @can_edit}>
                <:icon><Icons.icon_btn_save class="w-[14px] h-[14px]" /></:icon>
                {dgettext("dialogs", "Save settings")}
              </.button>
            </div>
          </form>

          <div class="grid gap-retro-8 md:grid-cols-2">
            <div>
              <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "Info")}</div>
              <pre
                id="admin-server-settings-info"
                class="shadow-retro-sunken bg-white min-h-[120px] max-h-[180px] overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap"
              ><%= @info || "" %></pre>
            </div>
            <div>
              <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "Settings")}</div>
              <div
                id="admin-server-settings-output"
                class="shadow-retro-sunken bg-white min-h-[120px] max-h-[180px] overflow-y-auto retro-scrollbar"
              >
                <.admin_table
                  table={@settings_table}
                  text={@settings_text}
                  testid="admin-server-settings-table"
                  empty_title={dgettext("dialogs", "No server settings configured")}
                />
              </div>
            </div>
          </div>

          <.inline_result result={@result} />
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, default: ""
  attr :disabled, :boolean, default: false
  attr :type, :string, default: "text"
  attr :min, :string, default: nil
  attr :max, :string, default: nil
  attr :rows, :integer, default: 2

  defp setting_field(assigns) do
    ~H"""
    <div>
      <label for={@id} class="block text-xs font-bold mb-retro-2">{@label}</label>
      <input
        :if={@type != "textarea"}
        id={@id}
        name={@name}
        type={@type}
        min={@min}
        max={@max}
        value={@value}
        disabled={@disabled}
        autocomplete="off"
        class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
      />
      <textarea
        :if={@type == "textarea"}
        id={@id}
        name={@name}
        disabled={@disabled}
        autocomplete="off"
        rows={@rows}
        class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm resize-y"
      >{@value}</textarea>
    </div>
    """
  end

  defp setting_value(values, key), do: values |> Map.get(key, "") |> to_string()
end
