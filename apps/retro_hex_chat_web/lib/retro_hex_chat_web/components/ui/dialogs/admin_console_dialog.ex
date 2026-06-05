defmodule RetroHexChatWeb.Components.UI.AdminConsoleDialog do
  @moduledoc """
  Admin Console dialog — a command-line style admin interface.

  Uses app design system primitives (Dialog, Button, Input).
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Tabs

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :active_tab, :string, default: "console"
  attr :results, :list, default: []
  attr :motd_content, :string, default: nil
  attr :motd_result, :any, default: nil
  attr :motd_editable, :boolean, default: false
  attr :broadcast_result, :any, default: nil
  attr :broadcast_can_wallops, :boolean, default: false
  attr :broadcast_can_announce, :boolean, default: false
  attr :turn_stats, :string, default: nil
  attr :turn_allocations, :string, default: nil
  attr :turn_result, :any, default: nil
  attr :turn_can_refresh, :boolean, default: false
  attr :audit_log_text, :string, default: nil
  attr :audit_log_last, :string, default: "20"
  attr :audit_log_user, :string, default: ""
  attr :audit_log_result, :any, default: nil
  attr :audit_log_can_refresh, :boolean, default: false
  attr :server_settings_info, :string, default: nil
  attr :server_settings_text, :string, default: nil
  attr :server_settings_values, :map, default: %{}
  attr :server_settings_result, :any, default: nil
  attr :server_settings_can_edit, :boolean, default: false
  attr :users_text, :string, default: nil
  attr :users_banlist_text, :string, default: nil
  attr :users_result, :any, default: nil
  attr :users_search, :string, default: ""
  attr :users_online_only, :boolean, default: false
  attr :users_info_nick, :string, default: ""
  attr :users_can_refresh, :boolean, default: false
  attr :channels_text, :string, default: nil
  attr :channels_banlist_text, :string, default: nil
  attr :channels_result, :any, default: nil
  attr :channels_search, :string, default: ""
  attr :channels_info_channel, :string, default: ""
  attr :channels_create_name, :string, default: ""
  attr :channels_can_refresh, :boolean, default: false
  attr :danger_zone_preview, :string, default: nil
  attr :danger_zone_result, :any, default: nil
  attr :danger_zone_confirm, :string, default: ""
  attr :danger_zone_server_name, :string, default: "RetroHexChat"
  attr :danger_zone_can_execute, :boolean, default: false
  attr :on_tab, :any, default: nil
  attr :on_motd_set, :any, default: nil
  attr :on_motd_clear, :any, default: nil
  attr :on_motd_refresh, :any, default: nil
  attr :on_broadcast_send, :any, default: nil
  attr :on_turn_refresh, :any, default: nil
  attr :on_audit_log_refresh, :any, default: nil
  attr :on_server_settings_save, :any, default: nil
  attr :on_server_settings_refresh, :any, default: nil
  attr :on_singleplayer, :any, default: nil
  attr :on_users_refresh, :any, default: nil
  attr :on_users_info, :any, default: nil
  attr :on_channels_refresh, :any, default: nil
  attr :on_channels_info, :any, default: nil
  attr :on_channels_create, :any, default: nil
  attr :on_danger_zone_preview, :any, default: nil
  attr :on_danger_zone_change, :any, default: nil
  attr :on_danger_zone_execute, :any, default: nil
  attr :on_close, :any, default: nil

  @spec admin_console_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_console_dialog(assigns) do
    ~H"""
    <div
      :if={@show}
      phx-window-keydown="close_admin_console"
      phx-key="Escape"
    >
      <.dialog id={@id} show={@show} class="max-w-lg">
        <.dialog_header id={@id} title={dgettext("dialogs", "Admin Console")}>
          <:icon><Icons.icon_dialog_admin_console class="w-[16px] h-[16px]" /></:icon>
        </.dialog_header>
        <.dialog_body>
          <.tabs :let={builder} id={"#{@id}-tabs"} default={@active_tab}>
            <.tabs_list class="flex flex-wrap">
              <.admin_tab
                builder={builder}
                value="server_settings"
                label={dgettext("dialogs", "Server Settings")}
                icon_fn={:icon_server}
                on_tab={@on_tab}
              />
              <.admin_tab
                builder={builder}
                value="users"
                label={dgettext("dialogs", "Users")}
                icon_fn={:icon_tab_nicklist}
                on_tab={@on_tab}
              />
              <.admin_tab
                builder={builder}
                value="channels"
                label={dgettext("dialogs", "Channels")}
                icon_fn={:icon_channels}
                on_tab={@on_tab}
              />
              <.admin_tab
                builder={builder}
                value="motd"
                label={dgettext("dialogs", "MOTD")}
                icon_fn={:icon_notepad}
                on_tab={@on_tab}
              />
              <.admin_tab
                builder={builder}
                value="broadcast"
                label={dgettext("dialogs", "Broadcast")}
                icon_fn={:icon_megaphone}
                on_tab={@on_tab}
              />
              <.admin_tab
                builder={builder}
                value="audit_log"
                label={dgettext("dialogs", "Audit Log")}
                icon_fn={:icon_notepad}
                on_tab={@on_tab}
              />
              <.admin_tab
                builder={builder}
                value="turn"
                label={dgettext("dialogs", "TURN")}
                icon_fn={:icon_websocket}
                on_tab={@on_tab}
              />
              <.admin_tab
                builder={builder}
                value="danger_zone"
                label={dgettext("dialogs", "Danger Zone")}
                icon_fn={:icon_warning}
                on_tab={@on_tab}
              />
              <.admin_tab
                builder={builder}
                value="console"
                label={dgettext("dialogs", "Console")}
                icon_fn={:icon_terminal}
                on_tab={@on_tab}
              />
            </.tabs_list>

            <.tabs_content
              :for={tab <- admin_shell_tabs()}
              value={tab}
              builder={builder}
              class="min-h-[240px]"
            >
              <div
                class="shadow-retro-sunken bg-white h-[240px]"
                data-testid={"admin-console-tab-#{tab}"}
              />
            </.tabs_content>

            <.tabs_content value="motd" builder={builder}>
              <.motd_tab
                content={@motd_content}
                result={@motd_result}
                editable={@motd_editable}
                on_set={@on_motd_set}
                on_clear={@on_motd_clear}
                on_refresh={@on_motd_refresh}
              />
            </.tabs_content>

            <.tabs_content value="broadcast" builder={builder}>
              <.broadcast_tab
                result={@broadcast_result}
                can_wallops={@broadcast_can_wallops}
                can_announce={@broadcast_can_announce}
                on_send={@on_broadcast_send}
              />
            </.tabs_content>

            <.tabs_content value="turn" builder={builder}>
              <.turn_tab
                stats={@turn_stats}
                allocations={@turn_allocations}
                result={@turn_result}
                can_refresh={@turn_can_refresh}
                on_refresh={@on_turn_refresh}
              />
            </.tabs_content>

            <.tabs_content value="audit_log" builder={builder}>
              <.audit_log_tab
                text={@audit_log_text}
                last={@audit_log_last}
                user={@audit_log_user}
                result={@audit_log_result}
                can_refresh={@audit_log_can_refresh}
                on_refresh={@on_audit_log_refresh}
              />
            </.tabs_content>

            <.tabs_content value="server_settings" builder={builder}>
              <.server_settings_tab
                info={@server_settings_info}
                settings_text={@server_settings_text}
                values={@server_settings_values}
                result={@server_settings_result}
                can_edit={@server_settings_can_edit}
                on_save={@on_server_settings_save}
                on_refresh={@on_server_settings_refresh}
                on_singleplayer={@on_singleplayer}
              />
            </.tabs_content>

            <.tabs_content value="users" builder={builder}>
              <.users_tab
                text={@users_text}
                banlist_text={@users_banlist_text}
                result={@users_result}
                search={@users_search}
                online_only={@users_online_only}
                info_nick={@users_info_nick}
                can_refresh={@users_can_refresh}
                on_refresh={@on_users_refresh}
                on_info={@on_users_info}
              />
            </.tabs_content>

            <.tabs_content value="channels" builder={builder}>
              <.channels_tab
                text={@channels_text}
                banlist_text={@channels_banlist_text}
                result={@channels_result}
                search={@channels_search}
                info_channel={@channels_info_channel}
                create_name={@channels_create_name}
                can_refresh={@channels_can_refresh}
                on_refresh={@on_channels_refresh}
                on_info={@on_channels_info}
                on_create={@on_channels_create}
              />
            </.tabs_content>

            <.tabs_content value="danger_zone" builder={builder}>
              <.danger_zone_tab
                preview={@danger_zone_preview}
                result={@danger_zone_result}
                confirm={@danger_zone_confirm}
                server_name={@danger_zone_server_name}
                can_execute={@danger_zone_can_execute}
                on_preview={@on_danger_zone_preview}
                on_change={@on_danger_zone_change}
                on_execute={@on_danger_zone_execute}
              />
            </.tabs_content>

            <.tabs_content value="console" builder={builder}>
              <.console_tab results={@results} />
            </.tabs_content>
          </.tabs>
        </.dialog_body>
        <.dialog_footer>
          <.button type="button" variant="outline" phx-click="clear_admin_console">
            <:icon><Icons.icon_trash class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Clear")}
          </.button>
          <.button type="button" phx-click={@on_close}>
            <:icon><Icons.icon_close class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Close")}
          </.button>
        </.dialog_footer>
      </.dialog>
    </div>
    """
  end

  attr :builder, :map, required: true
  attr :value, :string, required: true
  attr :label, :string, required: true
  attr :icon_fn, :atom, required: true
  attr :on_tab, :any, default: nil

  defp admin_tab(assigns) do
    ~H"""
    <.tabs_trigger
      builder={@builder}
      value={@value}
      phx-click={@on_tab}
      phx-value-tab={@value}
    >
      <:icon>{apply(Icons, @icon_fn, [%{class: "w-4 h-4"}])}</:icon>
      <span data-testid={"admin-console-tab-label-#{@value}"}>{@label}</span>
    </.tabs_trigger>
    """
  end

  attr :results, :list, default: []

  defp console_tab(assigns) do
    ~H"""
    <%!-- Output area --%>
    <div
      class="shadow-retro-sunken bg-black text-green-400 font-mono text-xs p-retro-8 h-[240px] overflow-y-auto mb-retro-8"
      id="admin-console-output"
      data-testid="admin-console-output"
    >
      <div
        :for={result <- @results}
        class={[
          "py-retro-2",
          if(Map.get(result, :status) == :error, do: "text-red-400", else: "text-green-400")
        ]}
      >
        <div :if={Map.get(result, :line)} class="text-yellow-400">
          &gt; {Map.get(result, :line, "")}
        </div>
        <span>
          {Map.get(result, :message, "")}
        </span>
      </div>
      <div :if={@results == []} class="text-muted-foreground">
        {dgettext(
          "dialogs",
          "Type a command and press Enter. Type \"help\" for available commands."
        )}
      </div>
    </div>

    <%!-- Input --%>
    <form phx-submit="execute_admin_console" class="flex gap-retro-4">
      <span class="text-sm font-mono font-bold shrink-0 self-start mt-retro-4">&gt;</span>
      <textarea
        id="admin-console-input"
        name="input"
        placeholder={dgettext("dialogs", "Enter admin command(s)... (one per line)")}
        class="flex-1 font-mono text-sm shadow-retro-sunken bg-white px-retro-4 py-retro-2 resize-y min-h-[28px] h-[56px]"
        autocomplete="off"
        rows="2"
      />
      <.button type="submit" size="sm" class="self-end">
        <:icon><Icons.icon_btn_play class="w-[14px] h-[14px]" /></:icon>
        {dgettext("dialogs", "Run")}
      </.button>
    </form>
    """
  end

  attr :content, :string, default: nil
  attr :result, :any, default: nil
  attr :editable, :boolean, default: false
  attr :on_set, :any, default: nil
  attr :on_clear, :any, default: nil
  attr :on_refresh, :any, default: nil

  defp motd_tab(assigns) do
    ~H"""
    <div class="space-y-retro-8" data-testid="admin-console-tab-motd">
      <div>
        <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "Current MOTD")}</div>
        <div
          id="admin-console-motd-current"
          class="shadow-retro-sunken bg-white min-h-[82px] max-h-[120px] overflow-y-auto p-retro-8 text-sm whitespace-pre-wrap"
        >
          <%= if present?(@content) do %>
            {@content}
          <% else %>
            <span class="text-muted-foreground">{dgettext("dialogs", "No MOTD has been set.")}</span>
          <% end %>
        </div>
      </div>

      <form id="admin-console-motd-form" phx-submit={@on_set} class="space-y-retro-4">
        <label for="admin-console-motd-input" class="block text-xs font-bold">
          {dgettext("dialogs", "New MOTD")}
        </label>
        <textarea
          id="admin-console-motd-input"
          name="motd"
          class="w-full shadow-retro-sunken bg-white px-retro-6 py-retro-4 text-sm resize-y min-h-[70px]"
          disabled={not @editable}
          autocomplete="off"
        >{@content || ""}</textarea>

        <div class="flex flex-wrap justify-end gap-retro-4">
          <.button type="button" size="sm" variant="outline" phx-click={@on_refresh}>
            <:icon><Icons.icon_btn_refresh class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Refresh")}
          </.button>
          <.button
            type="button"
            size="sm"
            variant="outline"
            phx-click={@on_clear}
            disabled={not @editable}
          >
            <:icon><Icons.icon_trash class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Clear MOTD")}
          </.button>
          <.button type="submit" size="sm" disabled={not @editable}>
            <:icon><Icons.icon_btn_save class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Set MOTD")}
          </.button>
        </div>
      </form>

      <.motd_result_strip result={@result} />
    </div>
    """
  end

  attr :result, :map, default: nil

  defp motd_result_strip(assigns) do
    ~H"""
    <div
      :if={@result}
      class={[
        "shadow-retro-sunken bg-black font-mono text-xs p-retro-6",
        if(Map.get(@result, :status) == :error, do: "text-red-400", else: "text-green-400")
      ]}
      data-testid="admin-console-motd-result"
    >
      {Map.get(@result, :message, "")}
    </div>
    """
  end

  attr :result, :any, default: nil
  attr :can_wallops, :boolean, default: false
  attr :can_announce, :boolean, default: false
  attr :on_send, :any, default: nil

  defp broadcast_tab(assigns) do
    ~H"""
    <div class="space-y-retro-8" data-testid="admin-console-tab-broadcast">
      <form id="admin-console-broadcast-form" phx-submit={@on_send} class="space-y-retro-8">
        <fieldset class="flex flex-wrap gap-retro-6">
          <label class="inline-flex items-center gap-retro-4 text-sm">
            <input
              type="radio"
              name="broadcast_type"
              value="wallops"
              checked
              disabled={not @can_wallops}
            />
            <span class="font-bold">{dgettext("dialogs", "Wallops")}</span>
          </label>
          <label class="inline-flex items-center gap-retro-4 text-sm">
            <input
              type="radio"
              name="broadcast_type"
              value="announce"
              disabled={not @can_announce}
            />
            <span class="font-bold">{dgettext("dialogs", "Announce")}</span>
          </label>
        </fieldset>

        <div>
          <label for="admin-console-broadcast-message" class="block text-xs font-bold mb-retro-4">
            {dgettext("dialogs", "Message")}
          </label>
          <textarea
            id="admin-console-broadcast-message"
            name="message"
            class="w-full shadow-retro-sunken bg-white px-retro-6 py-retro-4 text-sm resize-y min-h-[116px]"
            autocomplete="off"
          ></textarea>
        </div>

        <div class="flex justify-end">
          <.button
            type="submit"
            size="sm"
            disabled={not (@can_wallops or @can_announce)}
          >
            <:icon><Icons.icon_megaphone class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Send broadcast")}
          </.button>
        </div>
      </form>

      <.admin_inline_result result={@result} />
    </div>
    """
  end

  attr :stats, :string, default: nil
  attr :allocations, :string, default: nil
  attr :result, :any, default: nil
  attr :can_refresh, :boolean, default: false
  attr :on_refresh, :any, default: nil

  defp turn_tab(assigns) do
    ~H"""
    <div class="space-y-retro-8" data-testid="admin-console-tab-turn">
      <div class="flex justify-end">
        <.button
          type="button"
          size="sm"
          variant="outline"
          phx-click={@on_refresh}
          disabled={not @can_refresh}
        >
          <:icon><Icons.icon_btn_refresh class="w-[14px] h-[14px]" /></:icon>
          {dgettext("dialogs", "Refresh")}
        </.button>
      </div>

      <div class="grid gap-retro-8 md:grid-cols-2">
        <div>
          <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "Stats")}</div>
          <pre
            id="admin-console-turn-stats"
            class="shadow-retro-sunken bg-white min-h-[168px] max-h-[220px] overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap"
          ><%= @stats || "" %></pre>
        </div>
        <div>
          <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "Allocations")}</div>
          <pre
            id="admin-console-turn-allocations"
            class="shadow-retro-sunken bg-white min-h-[168px] max-h-[220px] overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap"
          ><%= @allocations || "" %></pre>
        </div>
      </div>

      <.admin_inline_result result={@result} />
    </div>
    """
  end

  attr :text, :string, default: nil
  attr :last, :string, default: "20"
  attr :user, :string, default: ""
  attr :result, :any, default: nil
  attr :can_refresh, :boolean, default: false
  attr :on_refresh, :any, default: nil

  defp audit_log_tab(assigns) do
    ~H"""
    <div class="space-y-retro-8" data-testid="admin-console-tab-audit-log">
      <form id="admin-console-audit-log-form" phx-submit={@on_refresh}>
        <div class="flex flex-wrap items-end gap-retro-6">
          <div class="w-[88px]">
            <label for="admin-console-audit-log-last" class="block text-xs font-bold mb-retro-2">
              {dgettext("dialogs", "Last")}
            </label>
            <input
              id="admin-console-audit-log-last"
              name="last"
              type="number"
              min="1"
              class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
              value={@last}
              disabled={not @can_refresh}
            />
          </div>
          <div class="flex-1 min-w-[160px]">
            <label for="admin-console-audit-log-user" class="block text-xs font-bold mb-retro-2">
              {dgettext("dialogs", "User")}
            </label>
            <input
              id="admin-console-audit-log-user"
              name="user"
              type="text"
              class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
              value={@user}
              autocomplete="off"
              disabled={not @can_refresh}
            />
          </div>
          <.button type="submit" size="sm" variant="outline" disabled={not @can_refresh}>
            <:icon><Icons.icon_btn_refresh class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Refresh")}
          </.button>
        </div>
      </form>

      <pre
        id="admin-console-audit-log-output"
        class="shadow-retro-sunken bg-white min-h-[190px] max-h-[260px] overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap"
      ><%= @text || "" %></pre>

      <.admin_inline_result result={@result} />
    </div>
    """
  end

  attr :info, :string, default: nil
  attr :settings_text, :string, default: nil
  attr :values, :map, default: %{}
  attr :result, :any, default: nil
  attr :can_edit, :boolean, default: false
  attr :on_save, :any, default: nil
  attr :on_refresh, :any, default: nil
  attr :on_singleplayer, :any, default: nil

  defp server_settings_tab(assigns) do
    ~H"""
    <div class="space-y-retro-8" data-testid="admin-console-tab-server-settings">
      <form id="admin-console-server-settings-form" phx-submit={@on_save} class="space-y-retro-8">
        <div class="grid gap-retro-6 md:grid-cols-2">
          <.settings_input
            id="admin-console-server-name"
            name="server_name"
            label={dgettext("dialogs", "Server name")}
            value={setting_value(@values, "server_name")}
            disabled={not @can_edit}
          />
          <.settings_input
            id="admin-console-max-channels"
            name="max_channels"
            label={dgettext("dialogs", "Max channels")}
            value={setting_value(@values, "max_channels")}
            disabled={not @can_edit}
            type="number"
            min="1"
          />
          <.settings_input
            id="admin-console-server-description"
            name="server_description"
            label={dgettext("dialogs", "Description")}
            value={setting_value(@values, "server_description")}
            disabled={not @can_edit}
          />
          <.settings_input
            id="admin-console-welcome-message"
            name="welcome_message"
            label={dgettext("dialogs", "Welcome message")}
            value={setting_value(@values, "welcome_message")}
            disabled={not @can_edit}
          />
          <div>
            <label for="admin-console-registration" class="block text-xs font-bold mb-retro-2">
              {dgettext("dialogs", "Registration")}
            </label>
            <select
              id="admin-console-registration"
              name="registration"
              class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
              disabled={not @can_edit}
            >
              <option value="open" selected={setting_value(@values, "registration") == "open"}>
                {dgettext("dialogs", "open")}
              </option>
              <option value="closed" selected={setting_value(@values, "registration") == "closed"}>
                {dgettext("dialogs", "closed")}
              </option>
            </select>
          </div>
          <.settings_input
            id="admin-console-whowas-retention"
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
            phx-click={@on_singleplayer}
            disabled={not @can_edit}
          >
            <:icon><Icons.icon_game_generic class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Start solo arcade (debug)")}
          </.button>
          <.button
            type="button"
            size="sm"
            variant="outline"
            phx-click={@on_refresh}
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
            id="admin-console-server-info"
            class="shadow-retro-sunken bg-white min-h-[120px] max-h-[180px] overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap"
          ><%= @info || "" %></pre>
        </div>
        <div>
          <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "Settings")}</div>
          <pre
            id="admin-console-server-settings-output"
            class="shadow-retro-sunken bg-white min-h-[120px] max-h-[180px] overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap"
          ><%= @settings_text || "" %></pre>
        </div>
      </div>

      <.admin_inline_result result={@result} />
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

  defp settings_input(assigns) do
    ~H"""
    <div>
      <label for={@id} class="block text-xs font-bold mb-retro-2">{@label}</label>
      <input
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
    </div>
    """
  end

  attr :text, :string, default: nil
  attr :banlist_text, :string, default: nil
  attr :result, :any, default: nil
  attr :search, :string, default: ""
  attr :online_only, :boolean, default: false
  attr :info_nick, :string, default: ""
  attr :can_refresh, :boolean, default: false
  attr :on_refresh, :any, default: nil
  attr :on_info, :any, default: nil

  defp users_tab(assigns) do
    ~H"""
    <div class="space-y-retro-8" data-testid="admin-console-tab-users">
      <form id="admin-console-users-form" phx-submit={@on_refresh}>
        <div class="flex flex-wrap items-end gap-retro-6">
          <div class="flex-1 min-w-[160px]">
            <label for="admin-console-users-search" class="block text-xs font-bold mb-retro-2">
              {dgettext("dialogs", "Search")}
            </label>
            <input
              id="admin-console-users-search"
              name="search"
              type="text"
              class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
              value={@search}
              autocomplete="off"
              disabled={not @can_refresh}
            />
          </div>
          <label class="inline-flex items-center gap-retro-4 text-sm min-h-[28px]">
            <input
              type="checkbox"
              name="online_only"
              value="true"
              checked={@online_only}
              disabled={not @can_refresh}
            />
            <span>{dgettext("dialogs", "Online only")}</span>
          </label>
          <.button type="submit" size="sm" variant="outline" disabled={not @can_refresh}>
            <:icon><Icons.icon_btn_refresh class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Refresh")}
          </.button>
        </div>
      </form>

      <pre
        id="admin-console-users-output"
        class="shadow-retro-sunken bg-white min-h-[140px] max-h-[210px] overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap"
      ><%= @text || "" %></pre>

      <form id="admin-console-user-info-form" phx-submit={@on_info}>
        <div class="flex flex-wrap items-end gap-retro-6">
          <div class="flex-1 min-w-[160px]">
            <label for="admin-console-user-info-nick" class="block text-xs font-bold mb-retro-2">
              {dgettext("dialogs", "Nick")}
            </label>
            <input
              id="admin-console-user-info-nick"
              name="nick"
              type="text"
              class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
              value={@info_nick}
              autocomplete="off"
              disabled={not @can_refresh}
            />
          </div>
          <.button type="submit" size="sm" disabled={not @can_refresh}>
            <:icon><Icons.icon_btn_info class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Info")}
          </.button>
        </div>
      </form>

      <div>
        <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "Ban list")}</div>
        <pre
          id="admin-console-users-banlist"
          class="shadow-retro-sunken bg-white min-h-[84px] max-h-[150px] overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap"
        ><%= @banlist_text || "" %></pre>
      </div>

      <.admin_inline_result result={@result} />
    </div>
    """
  end

  attr :text, :string, default: nil
  attr :banlist_text, :string, default: nil
  attr :result, :any, default: nil
  attr :search, :string, default: ""
  attr :info_channel, :string, default: ""
  attr :create_name, :string, default: ""
  attr :can_refresh, :boolean, default: false
  attr :on_refresh, :any, default: nil
  attr :on_info, :any, default: nil
  attr :on_create, :any, default: nil

  defp channels_tab(assigns) do
    ~H"""
    <div class="space-y-retro-8" data-testid="admin-console-tab-channels">
      <form id="admin-console-channels-form" phx-submit={@on_refresh}>
        <div class="flex flex-wrap items-end gap-retro-6">
          <div class="flex-1 min-w-[160px]">
            <label for="admin-console-channels-search" class="block text-xs font-bold mb-retro-2">
              {dgettext("dialogs", "Search")}
            </label>
            <input
              id="admin-console-channels-search"
              name="search"
              type="text"
              class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
              value={@search}
              autocomplete="off"
              disabled={not @can_refresh}
            />
          </div>
          <.button type="submit" size="sm" variant="outline" disabled={not @can_refresh}>
            <:icon><Icons.icon_btn_refresh class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Refresh")}
          </.button>
        </div>
      </form>

      <pre
        id="admin-console-channels-output"
        class="shadow-retro-sunken bg-white min-h-[120px] max-h-[190px] overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap"
      ><%= @text || "" %></pre>

      <div class="grid gap-retro-8 md:grid-cols-2">
        <form id="admin-console-channel-info-form" phx-submit={@on_info}>
          <div class="flex flex-wrap items-end gap-retro-6">
            <div class="flex-1 min-w-[140px]">
              <label for="admin-console-channel-info-name" class="block text-xs font-bold mb-retro-2">
                {dgettext("dialogs", "Channel")}
              </label>
              <input
                id="admin-console-channel-info-name"
                name="channel"
                type="text"
                class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
                value={@info_channel}
                autocomplete="off"
                disabled={not @can_refresh}
              />
            </div>
            <.button type="submit" size="sm" disabled={not @can_refresh}>
              <:icon><Icons.icon_btn_info class="w-[14px] h-[14px]" /></:icon>
              {dgettext("dialogs", "Info")}
            </.button>
          </div>
        </form>

        <form id="admin-console-channel-create-form" phx-submit={@on_create}>
          <div class="flex flex-wrap items-end gap-retro-6">
            <div class="flex-1 min-w-[140px]">
              <label
                for="admin-console-channel-create-name"
                class="block text-xs font-bold mb-retro-2"
              >
                {dgettext("dialogs", "New channel")}
              </label>
              <input
                id="admin-console-channel-create-name"
                name="channel"
                type="text"
                class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
                value={@create_name}
                autocomplete="off"
                disabled={not @can_refresh}
              />
            </div>
            <.button type="submit" size="sm" disabled={not @can_refresh}>
              <:icon><Icons.icon_btn_add class="w-[14px] h-[14px]" /></:icon>
              {dgettext("dialogs", "Create")}
            </.button>
          </div>
        </form>
      </div>

      <div>
        <div class="text-xs font-bold mb-retro-4">{dgettext("dialogs", "Ban list")}</div>
        <pre
          id="admin-console-channels-banlist"
          class="shadow-retro-sunken bg-white min-h-[84px] max-h-[150px] overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap"
        ><%= @banlist_text || "" %></pre>
      </div>

      <.admin_inline_result result={@result} />
    </div>
    """
  end

  attr :preview, :string, default: nil
  attr :result, :any, default: nil
  attr :confirm, :string, default: ""
  attr :server_name, :string, default: "RetroHexChat"
  attr :can_execute, :boolean, default: false
  attr :on_preview, :any, default: nil
  attr :on_change, :any, default: nil
  attr :on_execute, :any, default: nil

  defp danger_zone_tab(assigns) do
    assigns =
      assign(assigns,
        confirmation_matches?: assigns.can_execute and assigns.confirm == assigns.server_name
      )

    ~H"""
    <div class="space-y-retro-8" data-testid="admin-console-tab-danger-zone">
      <div class="shadow-retro-sunken bg-white p-retro-8 text-sm">
        <div class="font-bold text-destructive">{dgettext("dialogs", "THIS CANNOT BE UNDONE")}</div>
        <div class="mt-retro-4">
          {dgettext(
            "dialogs",
            "Preserved: admin_roles, audit_logs, server_bans, server_settings"
          )}
        </div>
      </div>

      <pre
        id="admin-console-danger-preview"
        class="shadow-retro-sunken bg-white min-h-[136px] max-h-[220px] overflow-y-auto p-retro-8 text-xs whitespace-pre-wrap"
      ><%= @preview || "" %></pre>

      <form
        id="admin-console-danger-zone-form"
        phx-change={@on_change}
        phx-submit={@on_execute}
        class="space-y-retro-6"
      >
        <label for="admin-console-danger-confirm" class="block text-xs font-bold">
          {dgettext("dialogs", "Type the server name to confirm: %{server_name}",
            server_name: @server_name
          )}
        </label>
        <input
          id="admin-console-danger-confirm"
          name="confirm"
          type="text"
          value={@confirm}
          class="w-full shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
          autocomplete="off"
          disabled={not @can_execute}
        />

        <div class="flex flex-wrap justify-end gap-retro-4">
          <.button
            type="button"
            size="sm"
            variant="outline"
            phx-click={@on_preview}
            disabled={not @can_execute}
          >
            <:icon><Icons.icon_btn_refresh class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Refresh preview")}
          </.button>
          <.button
            type="submit"
            size="sm"
            variant="destructive"
            disabled={not @confirmation_matches?}
          >
            <:icon><Icons.icon_warning class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "NUKE EVERYTHING")}
          </.button>
        </div>
      </form>

      <.admin_inline_result result={@result} />
    </div>
    """
  end

  attr :result, :any, default: nil

  defp admin_inline_result(assigns) do
    ~H"""
    <div
      :if={@result}
      class={[
        "shadow-retro-sunken bg-black font-mono text-xs p-retro-6",
        if(Map.get(@result, :status) == :error, do: "text-red-400", else: "text-green-400")
      ]}
      data-testid="admin-console-inline-result"
    >
      {Map.get(@result, :message, "")}
    </div>
    """
  end

  defp present?(value), do: is_binary(value) and String.trim(value) != ""

  defp setting_value(values, key), do: values |> Map.get(key, "") |> to_string()

  @spec admin_shell_tabs() :: [String.t()]
  defp admin_shell_tabs do
    ~w()
  end
end
