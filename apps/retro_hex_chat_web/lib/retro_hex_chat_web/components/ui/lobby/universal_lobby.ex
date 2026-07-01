defmodule RetroHexChatWeb.Components.UI.Lobby.UniversalLobby do
  @moduledoc """
  Universal lobby master component — the complete `/lobby` session UI, rendered as a
  Win98 desktop.

  Every P2P feature runs concurrently over one persistent connection and lives in its
  own draggable window: connection telemetry (pinned), chat, audio/video call, file
  transfer and games. Navigation is the taskbar Start menu; window chrome state
  (position, size, z-order, minimize/maximize, open/closed) is owned client-side by
  the `WindowManagerHook` and persisted to localStorage.

  Composed entirely from primitives: the generic `Desktop` window-manager family
  (`desktop`/`desktop_window`/`taskbar`/...), the stateful window islands
  (`ChatIsland` owns the message list; `GameIsland`, `FileIsland` and `MediaIsland`
  own their feature state and drive their own windows), the shared connection diagram
  and network telemetry panel — no bespoke markup. The Statistics window (telemetry
  aggregator) and the taskbar badges stay host-owned, reading the islands' mirrored
  summaries. Closing a feature window only hides it; the feature (and its hook) keeps
  running until leave or inactivity.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Alert
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.AppHeader
  import RetroHexChatWeb.Components.UI.AboutDialog
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.Components.UI.Lobby.LobbyMenuBar
  import RetroHexChatWeb.Components.UI.Lobby.LobbyStatusBar
  import RetroHexChatWeb.Components.UI.Lobby.LobbyNetworkPanel
  alias RetroHexChatWeb.App.LobbyLive.Components.ChatIsland
  alias RetroHexChatWeb.App.LobbyLive.Components.FileIsland
  alias RetroHexChatWeb.App.LobbyLive.Components.GameIsland
  alias RetroHexChatWeb.App.LobbyLive.Components.MediaIsland
  alias RetroHexChatWeb.Icons

  # Identity & status
  attr :token, :string, required: true
  attr :user_id, :integer, required: true
  attr :nickname, :string, required: true
  attr :peer_nick, :string, required: true
  attr :peer_online, :boolean, default: false
  attr :session_status, :string, required: true

  attr :ever_connected, :boolean,
    default: false,
    doc: "latches true on first connect; keeps feature hooks mounted across status blips"

  attr :connection_label, :string, default: nil
  attr :local_info, :map, default: %{}
  attr :peer_info, :map, default: %{}

  # Terminal state
  attr :expired, :boolean, default: false
  attr :session_closed, :boolean, default: false
  attr :ended_reason, :string, default: nil

  # Session controls
  attr :turn_configured, :boolean, default: false
  attr :turn_only, :boolean, default: false
  attr :inactivity_warning, :boolean, default: false

  # Media — the island owns the call; the host mirrors this summary
  # (type/duration/quality_label) for the badge and the conn strip.
  attr :call_summary, :map, default: nil
  # Statistics window (host-owned aggregator)
  attr :stats, :map, default: nil
  attr :network_info_open, :boolean, default: false

  # File transfer — the island owns the transfer; the host mirrors this summary
  # (status/sender_nick/percent/speed/file_name) for the badge and the conn strip.
  attr :file_summary, :map, default: nil

  # Games — the island owns the game state; the host mirrors only this badge flag.
  attr :game_active, :boolean, default: false

  attr :rest, :global

  @spec universal_lobby(map()) :: Phoenix.LiveView.Rendered.t()
  def universal_lobby(assigns) do
    assigns =
      assigns
      |> assign(:connected, assigns.session_status == "connected")
      |> assign(:mounted, assigns.ever_connected or assigns.session_status == "connected")
      |> assign(:call_active, assigns.call_summary != nil)
      |> assign(
        :file_active,
        Map.get(assigns.file_summary || %{}, :status) in ~w(offering offer_received transferring paused)
      )

    ~H"""
    <div class="lobby flex h-screen flex-col bg-background text-foreground" {@rest}>
      <.lobby_ended :if={@expired or @session_closed} reason={@ended_reason} />

      <div :if={!(@expired or @session_closed)} class="flex h-full flex-col">
        <%!-- Persistent connection hook (always mounted once joined) --%>
        <div id="lobby-webrtc" phx-hook="LobbyWebRTCHook" phx-update="ignore" class="u-hidden"></div>

        <%!-- The desktop is intentionally chrome-free (future home for shortcuts):
              identity, connection state, privacy and the clock all live inside the
              Statistics window. Only a transient inactivity warning may appear. --%>
        <.alert :if={@inactivity_warning} variant="destructive" class="rounded-none">
          <:icon><Icons.icon_warning class="h-4 w-4" /></:icon>
          <.alert_description>
            {dgettext("lobby", "This lobby will close soon due to inactivity.")}
          </.alert_description>
        </.alert>

        <.desktop
          id="lobby-desktop"
          persist_key="lobby"
          persist={false}
          data-testid="lobby-desktop"
        >
          <:header>
            <.app_header on_logo_click={show_modal("about-dialog")}>
              <:panels>
                <.lobby_menu_bar
                  id="lobby-menubar"
                  phx-hook="MenuBarHook"
                  connected={@connected}
                  call_active={@call_active}
                  turn_configured={@turn_configured}
                  turn_only={@turn_only}
                />
                <.lobby_status_bar
                  class="ml-auto"
                  nickname={@nickname}
                  peer_nick={@peer_nick}
                  peer_online={@peer_online}
                  connection_label={@connection_label}
                  stats={@stats}
                />
              </:panels>
            </.app_header>
          </:header>
          <:shortcuts>
            <.desktop_shortcut
              window="call"
              label={dgettext("lobby", "Call")}
              data-testid="lobby-shortcut-call"
            >
              <:icon><Icons.icon_camera class="h-8 w-8" /></:icon>
            </.desktop_shortcut>
            <.desktop_shortcut
              window="file"
              label={dgettext("lobby", "Files")}
              data-testid="lobby-shortcut-file"
            >
              <:icon><Icons.icon_file_send class="h-8 w-8" /></:icon>
            </.desktop_shortcut>
            <.desktop_shortcut
              window="game"
              label={dgettext("lobby", "Games")}
              data-testid="lobby-shortcut-game"
            >
              <:icon><Icons.icon_joystick class="h-8 w-8" /></:icon>
            </.desktop_shortcut>
            <.desktop_shortcut
              window="chat"
              label={dgettext("lobby", "Chat")}
              data-testid="lobby-shortcut-chat"
            >
              <:icon><Icons.icon_chat class="h-8 w-8" /></:icon>
            </.desktop_shortcut>
            <.desktop_shortcut
              window="conn"
              label={dgettext("lobby", "Statistics")}
              data-testid="lobby-shortcut-conn"
            >
              <:icon><Icons.icon_status_signal class="h-8 w-8" /></:icon>
            </.desktop_shortcut>
          </:shortcuts>
          <%!-- Statistics — the lobby's telemetry home: a Network tab (full
                connection diagram + whois + connection quality) and one tab per
                media/data channel. Pinned: it cannot be closed. Identity, live
                connection state and the clock live in the top bar. --%>
          <.desktop_window
            id="conn"
            title={dgettext("lobby", "Statistics")}
            pinned
            default_x={560}
            default_y={16}
            width={380}
            height={500}
            data-testid="lobby-window-conn"
          >
            <:icon><Icons.icon_status_signal class="h-4 w-4" /></:icon>
            <.lobby_network_panel
              stats={@stats}
              info_open={@network_info_open}
              nickname={@nickname}
              peer_nick={@peer_nick}
              peer_online={@peer_online}
              session_status={@session_status}
              connection_label={@connection_label}
              local_info={@local_info}
              peer_info={@peer_info}
              call_summary={@call_summary}
              file_summary={@file_summary}
              turn_only={@turn_only}
            />
          </.desktop_window>

          <%!-- Chat — open by default --%>
          <.desktop_window
            id="chat"
            title={dgettext("lobby", "Chat")}
            default_x={16}
            default_y={300}
            width={300}
            height={280}
            body_class="p-1"
            data-testid="lobby-window-chat"
          >
            <:icon><Icons.icon_chat class="h-4 w-4" /></:icon>
            <.live_component module={ChatIsland} id="lobby-chat" />
          </.desktop_window>

          <%!-- Audio/video call --%>
          <.desktop_window
            id="call"
            title={if @peer_nick in [nil, ""], do: dgettext("lobby", "Call"), else: @peer_nick}
            open={false}
            on_close="end_call"
            default_x={16}
            default_y={16}
            width={460}
            body_class="p-1"
            data-testid="lobby-window-call"
          >
            <:icon><Icons.icon_camera class="h-4 w-4" /></:icon>
            <.live_component
              module={MediaIsland}
              id="lobby-media-island"
              connected={@mounted}
              nickname={@nickname}
              peer_nick={@peer_nick}
              token={@token}
              user_id={@user_id}
            />
          </.desktop_window>

          <%!-- File transfer --%>
          <.desktop_window
            id="file"
            title={dgettext("lobby", "Files")}
            open={false}
            on_close="ft_cancel"
            default_x={360}
            default_y={300}
            width={320}
            body_class="p-1"
            data-testid="lobby-window-file"
          >
            <:icon><Icons.icon_file_send class="h-4 w-4" /></:icon>
            <.live_component
              module={FileIsland}
              id="lobby-file"
              connected={@mounted}
              nickname={@nickname}
              peer_nick={@peer_nick}
              token={@token}
            />
          </.desktop_window>

          <%!-- Games --%>
          <.desktop_window
            id="game"
            title={dgettext("lobby", "Games")}
            open={false}
            on_close="end_game"
            default_x={120}
            default_y={48}
            width={680}
            body_class="p-1"
            data-testid="lobby-window-game"
          >
            <:icon><Icons.icon_joystick class="h-4 w-4" /></:icon>
            <.live_component
              module={GameIsland}
              id="lobby-game"
              connected={@mounted}
              peer_nick={@peer_nick}
            />
          </.desktop_window>

          <:taskbar>
            <.taskbar>
              <:start>
                <div class="relative">
                  <.start_button label={dgettext("lobby", "Lobby")}>
                    <:icon><Icons.icon_hex_stone class="h-4 w-4" /></:icon>
                  </.start_button>
                  <.start_menu id="lobby-start-menu">
                    <.start_menu_item
                      phx-click="start_call"
                      phx-value-type="audio"
                      disabled={not @connected or @call_active}
                      label={dgettext("lobby", "Start audio")}
                      data-testid="lobby-menu-audio"
                    >
                      <:icon><Icons.icon_microphone class="h-4 w-4" /></:icon>
                    </.start_menu_item>
                    <.start_menu_item
                      phx-click="start_call"
                      phx-value-type="video"
                      disabled={not @connected or @call_active}
                      label={dgettext("lobby", "Start video")}
                      data-testid="lobby-menu-video"
                    >
                      <:icon><Icons.icon_camera class="h-4 w-4" /></:icon>
                    </.start_menu_item>
                    <.start_menu_item
                      data-window-open="file"
                      disabled={not @connected}
                      label={dgettext("lobby", "Send a file")}
                      data-testid="lobby-menu-file"
                    >
                      <:icon><Icons.icon_file_send class="h-4 w-4" /></:icon>
                    </.start_menu_item>
                    <.start_menu_item
                      data-window-open="game"
                      disabled={not @connected}
                      label={dgettext("lobby", "Play a game")}
                      data-testid="lobby-menu-game"
                    >
                      <:icon><Icons.icon_joystick class="h-4 w-4" /></:icon>
                    </.start_menu_item>
                    <.start_menu_separator />
                    <.start_menu_item data-window-open="chat" label={dgettext("lobby", "Chat")}>
                      <:icon><Icons.icon_chat class="h-4 w-4" /></:icon>
                    </.start_menu_item>
                    <.start_menu_item data-window-open="conn" label={dgettext("lobby", "Statistics")}>
                      <:icon><Icons.icon_status_signal class="h-4 w-4" /></:icon>
                    </.start_menu_item>
                    <.start_menu_separator />
                    <.start_menu_item
                      :if={@turn_configured}
                      phx-click="toggle_privacy_mode"
                      label={
                        if @turn_only,
                          do: dgettext("lobby", "Privacy: ON"),
                          else: dgettext("lobby", "Privacy: OFF")
                      }
                      data-testid="lobby-privacy"
                    >
                      <:icon><Icons.icon_privacy class="h-4 w-4" /></:icon>
                    </.start_menu_item>
                    <.start_menu_item
                      phx-click="leave_lobby"
                      label={dgettext("lobby", "Leave lobby")}
                      data-testid="lobby-leave"
                    >
                      <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
                    </.start_menu_item>
                  </.start_menu>
                </div>
              </:start>

              <.taskbar_button window="conn" label={dgettext("lobby", "Statistics")}>
                <:icon><Icons.icon_status_signal class="h-4 w-4" /></:icon>
              </.taskbar_button>
              <.taskbar_button window="chat" label={dgettext("lobby", "Chat")}>
                <:icon><Icons.icon_chat class="h-4 w-4" /></:icon>
              </.taskbar_button>
              <.taskbar_button
                window="call"
                label={dgettext("lobby", "Call")}
                badge={if @call_active, do: @call_summary[:duration]}
              >
                <:icon><Icons.icon_camera class="h-4 w-4" /></:icon>
              </.taskbar_button>
              <.taskbar_button
                window="file"
                label={dgettext("lobby", "Files")}
                badge={if @file_active, do: "#{@file_summary[:percent] || 0}%"}
              >
                <:icon><Icons.icon_file_send class="h-4 w-4" /></:icon>
              </.taskbar_button>
              <.taskbar_button
                window="game"
                label={dgettext("lobby", "Games")}
                badge={if @game_active, do: "●"}
              >
                <:icon><Icons.icon_joystick class="h-4 w-4" /></:icon>
              </.taskbar_button>
            </.taskbar>
          </:taskbar>
        </.desktop>

        <.about_dialog id="about-dialog" />
      </div>
    </div>
    """
  end

  # --- Terminal state ---

  attr :reason, :string, default: nil

  defp lobby_ended(assigns) do
    ~H"""
    <div class="flex flex-1 items-center justify-center p-8">
      <div class="shadow-retro-raised bg-accent max-w-md p-6 text-center" data-testid="lobby-ended">
        <Icons.icon_warning class="mx-auto mb-3 h-8 w-8" />
        <p class="mb-3 text-sm font-bold">{dgettext("lobby", "Lobby ended")}</p>
        <p class="text-muted-foreground mb-4 text-xs">{@reason}</p>
        <.link navigate="/chat">
          <.button size="sm" variant="outline">
            <:icon><Icons.icon_chat class="h-4 w-4" /></:icon>
            {dgettext("lobby", "Back to chat")}
          </.button>
        </.link>
      </div>
    </div>
    """
  end
end
