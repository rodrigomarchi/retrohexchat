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
  attr :on_tab, :any, default: nil
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

  @spec admin_shell_tabs() :: [String.t()]
  defp admin_shell_tabs do
    ~w(server_settings users channels motd broadcast audit_log turn danger_zone)
  end
end
