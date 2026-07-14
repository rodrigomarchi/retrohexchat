defmodule RetroHexChatWeb.Components.UI.ChatTaskbar do
  @moduledoc """
  Visual taskbar composition for the main chat desktop.

  The LiveView owns window state and session state. This component only renders
  the taskbar buttons, labels, icons and tray for those read models.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.StartMenuApp

  alias RetroHexChatWeb.Icons

  attr :open_windows, :any, default: MapSet.new()
  attr :is_admin, :boolean, default: false
  attr :p2p_session, :map, default: nil
  attr :group_call, :map, default: nil
  attr :arcade_session, :map, default: nil
  attr :cc_window_channel, :string, default: nil

  @spec chat_taskbar(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_taskbar(assigns) do
    ~H"""
    <.taskbar id="chat-taskbar">
      <:start>
        <.start_menu_app id="chat-start-menu" is_admin={@is_admin} p2p_active={@p2p_session != nil} />
      </:start>

      <.taskbar_button window="chat" label={dgettext("chat", "RetroHexChat")}>
        <:icon><Icons.icon_chat class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button window="url-catcher" label={dgettext("chat", "URL Catcher")}>
        <:icon><Icons.icon_link class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button window="channel-list" label={dgettext("chat", "Channel List")}>
        <:icon><Icons.icon_channels class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={window_open?(@open_windows, "cheatsheet")}
        window="cheatsheet"
        label={dgettext("chat", "Keyboard Shortcuts")}
      >
        <:icon><Icons.icon_dialog_cheatsheet class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={@cc_window_channel}
        window="channel-central"
        label={dgettext("chat", "Channel Central")}
      >
        <:icon><Icons.icon_dialog_channel_central class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={window_open?(@open_windows, "account")}
        window="account"
        label={dgettext("chat", "Account")}
      >
        <:icon><Icons.icon_status_user class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={window_open?(@open_windows, "user-lookup")}
        window="user-lookup"
        label={dgettext("chat", "User Lookup")}
      >
        <:icon><Icons.icon_btn_search class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={@is_admin and window_open?(@open_windows, "admin-console-dialog")}
        window="admin-console-dialog"
        label={dgettext("chat", "Admin Console")}
      >
        <:icon><Icons.icon_dialog_admin_console class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={@is_admin and window_open?(@open_windows, "bot-management-dialog")}
        window="bot-management-dialog"
        label={dgettext("chat", "Bot Management")}
      >
        <:icon><Icons.icon_btn_bot_management class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={window_open?(@open_windows, "timers")}
        window="timers"
        label={dgettext("chat", "Timers")}
      >
        <:icon><Icons.icon_btn_timers class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={@p2p_session && window_open?(@open_windows, "p2p-stats")}
        window="p2p-stats"
        label={dgettext("chat", "P2P Statistics")}
      >
        <:icon><Icons.icon_protocol_p2p_compact class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={p2p_ready?(@p2p_session)}
        window="p2p-call"
        label={p2p_call_label(@p2p_session)}
      >
        <:icon><Icons.icon_camera class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={p2p_ready?(@p2p_session)}
        window="p2p-files"
        label={dgettext("chat", "P2P Files")}
      >
        <:icon><Icons.icon_file_send class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={@group_call && window_open?(@open_windows, "group-call-stats")}
        window="group-call-stats"
        label={dgettext("group_call", "Conference Statistics")}
        data-testid="group-call-stats-taskbar"
      >
        <:icon><Icons.icon_protocol_conference_compact class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={@group_call}
        window="group-call"
        label={group_call_label(@group_call)}
        data-testid="group-call-taskbar"
      >
        <:icon><Icons.icon_protocol_conference_compact class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={@p2p_session && window_open?(@open_windows, "p2p-games")}
        window="p2p-games"
        label={dgettext("chat", "P2P Games")}
      >
        <:icon><Icons.icon_game_arcade class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={@arcade_session && window_open?(@open_windows, "arcade-games")}
        window="arcade-games"
        label={dgettext("chat", "Arcade")}
      >
        <:icon><Icons.icon_game_arcade class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={window_open?(@open_windows, "highlight")}
        window="highlight"
        label={dgettext("chat", "Highlight Words")}
      >
        <:icon><Icons.icon_star class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={window_open?(@open_windows, "sound-settings")}
        window="sound-settings"
        label={dgettext("chat", "Sound Settings")}
      >
        <:icon><Icons.icon_dialog_sound class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={window_open?(@open_windows, "flood-protection")}
        window="flood-protection"
        label={dgettext("chat", "Flood Protection")}
      >
        <:icon><Icons.icon_dialog_flood class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={window_open?(@open_windows, "alias")}
        window="alias"
        label={dgettext("chat", "Alias Editor")}
      >
        <:icon><Icons.icon_dialog_alias class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={window_open?(@open_windows, "custom-menus")}
        window="custom-menus"
        label={dgettext("chat", "Custom Menus")}
      >
        <:icon><Icons.icon_dialog_custom_menus class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={window_open?(@open_windows, "auto-respond")}
        window="auto-respond"
        label={dgettext("chat", "Auto Respond")}
      >
        <:icon><Icons.icon_dialog_auto_respond class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={window_open?(@open_windows, "perform")}
        window="perform"
        label={dgettext("chat", "Perform")}
      >
        <:icon><Icons.icon_dialog_perform class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={window_open?(@open_windows, "notify-list")}
        window="notify-list"
        label={dgettext("chat", "Notify List")}
      >
        <:icon><Icons.icon_tab_notify class="h-4 w-4" /></:icon>
      </.taskbar_button>
      <.taskbar_button
        :if={window_open?(@open_windows, "address-book")}
        window="address-book"
        label={dgettext("chat", "Address Book")}
      >
        <:icon><Icons.icon_dialog_address_book class="h-4 w-4" /></:icon>
      </.taskbar_button>

      <:tray>
        <.desktop_tray>
          <span id="chat-tray-clock" phx-hook="ClockHook" class="font-mono tabular-nums"></span>
        </.desktop_tray>
      </:tray>
    </.taskbar>
    """
  end

  defp window_open?(open_windows, id) when is_binary(id) do
    MapSet.member?(open_windows || MapSet.new(), id)
  end

  defp p2p_ready?(%{state: state}), do: state != :invite_sent
  defp p2p_ready?(_p2p_session), do: false

  defp p2p_call_label(%{peer_nick: peer_nick}) when peer_nick not in [nil, ""] do
    peer_nick
  end

  defp p2p_call_label(_p2p_session), do: dgettext("chat", "P2P Call")

  defp group_call_label(%{channel_name: channel_name}) when channel_name not in [nil, ""] do
    channel_name
  end

  defp group_call_label(_group_call), do: dgettext("group_call", "Group Call")
end
