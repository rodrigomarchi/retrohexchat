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
  attr :on_tab, :any, default: nil
  attr :on_motd_set, :any, default: nil
  attr :on_motd_clear, :any, default: nil
  attr :on_motd_refresh, :any, default: nil
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

  defp present?(value), do: is_binary(value) and String.trim(value) != ""

  @spec admin_shell_tabs() :: [String.t()]
  defp admin_shell_tabs do
    ~w(server_settings users channels broadcast audit_log turn danger_zone)
  end
end
