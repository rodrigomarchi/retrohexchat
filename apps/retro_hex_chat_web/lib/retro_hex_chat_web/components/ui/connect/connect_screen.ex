defmodule RetroHexChatWeb.Components.UI.ConnectScreen do
  @moduledoc """
  Desktop chrome for the pre-auth connect screen.

  This component owns everything around the connect window — desktop, header,
  menu bar, status bar, taskbar and About dialog — and renders the window body
  from a slot. The body itself is
  `RetroHexChatWeb.Components.UI.ConnectFormPanel`, driven by a LiveComponent,
  so the same form also runs inside a window on the public landing pages.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.AboutDialog
  import RetroHexChatWeb.Components.UI.Alert
  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.ConnectStatusBar
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.Components.UI.MenuBarApp
  import RetroHexChatWeb.Components.UI.StartMenuApp

  alias RetroHexChatWeb.Icons

  attr :step, :atom, required: true, values: [:nickname, :password, :register]
  attr :flash, :map, default: %{}
  slot :inner_block, required: true

  @spec connect_screen(map()) :: Phoenix.LiveView.Rendered.t()
  def connect_screen(assigns) do
    ~H"""
    <div id="connect-root" class="flex flex-col h-screen bg-background">
      <.desktop id="connect-desktop" persist={false} data-testid="connect-desktop">
        <:header>
          <.app_header on_logo_click={show_modal("about-dialog")}>
            <:panels>
              <.menu_bar_app
                id="menubar"
                phx-hook="MenuBarHook"
                connected={false}
                on_action="menu_action"
              />
              <.connect_status_bar class="ml-auto" step={@step} />
            </:panels>
          </.app_header>
        </:header>

        <.connect_window flash={@flash}>
          {render_slot(@inner_block)}
        </.connect_window>

        <:taskbar>
          <.connect_taskbar />
        </:taskbar>
      </.desktop>

      <.about_dialog id="about-dialog" />
    </div>
    """
  end

  attr :flash, :map, default: %{}
  slot :inner_block, required: true

  defp connect_window(assigns) do
    ~H"""
    <.desktop_window
      id="connect"
      title={dgettext("connect", "Connect to RetroHexChat")}
      pinned
      default_centered
      width={560}
      min_width={360}
      resizable={false}
      body_class="p-4"
      data-testid="connect-window"
    >
      <:icon><Icons.icon_connect class="w-4 h-4" /></:icon>
      <.alert
        :if={@flash["error"]}
        variant="destructive"
        class="mb-4"
        data-testid="session-alert"
      >
        <:icon><Icons.icon_warning /></:icon>
        <.alert_description>{@flash["error"]}</.alert_description>
      </.alert>

      {render_slot(@inner_block)}
    </.desktop_window>
    """
  end

  defp connect_taskbar(assigns) do
    ~H"""
    <.taskbar>
      <:start>
        <.start_menu_app
          id="connect-start-menu"
          screen={:connect}
          windows={[
            %{id: "connect", label: dgettext("connect", "Connect"), icon_fn: :icon_connect}
          ]}
        />
      </:start>
      <.taskbar_button window="connect" label={dgettext("connect", "Connect")}>
        <:icon><Icons.icon_connect class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <:tray>
        <.desktop_tray>
          <span id="connect-tray-clock" data-clock phx-hook="ClockHook" class="font-mono tabular-nums">
          </span>
        </.desktop_tray>
      </:tray>
    </.taskbar>
    """
  end
end
