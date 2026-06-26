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
  (`desktop`/`desktop_window`/`taskbar`/...), the per-feature panel components
  (`media_panel`/`file_panel`/`game_panel`/`chat_panel`), the shared connection
  diagram and network telemetry panel — no bespoke markup. Closing a feature window
  only hides it; the feature (and its hook) keeps running until leave or inactivity.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Toolbar
  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Alert
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.P2PConnectionDiagram
  import RetroHexChatWeb.Components.UI.Lobby.LobbyNetworkPanel
  import RetroHexChatWeb.Components.UI.Lobby.MediaPanel
  import RetroHexChatWeb.Components.UI.Lobby.FilePanel
  import RetroHexChatWeb.Components.UI.Lobby.GamePanel
  import RetroHexChatWeb.Components.UI.Lobby.ChatPanel

  alias RetroHexChatWeb.Icons

  # Identity & status
  attr :token, :string, required: true
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

  # Media
  attr :call, :map, default: nil
  attr :call_layout, :string, default: "focus", values: ~w(focus side_by_side maximized)
  attr :local_muted, :boolean, default: false
  attr :local_camera_off, :boolean, default: false
  attr :peer_media, :map, default: %{audio: false, video: false}
  attr :devices, :map, default: nil
  attr :stats, :map, default: nil
  attr :network_info_open, :boolean, default: false

  # File transfer
  attr :file_transfer, :map, default: nil

  # Games
  attr :game, :map, default: %{status: "idle", game_id: nil, is_host: false}
  attr :game_request, :map, default: nil
  attr :game_outgoing, :boolean, default: false
  attr :games, :list, default: []

  # Chat
  attr :messages, :list, default: []

  attr :rest, :global

  @spec universal_lobby(map()) :: Phoenix.LiveView.Rendered.t()
  def universal_lobby(assigns) do
    assigns =
      assigns
      |> assign(:connected, assigns.session_status == "connected")
      |> assign(:mounted, assigns.ever_connected or assigns.session_status == "connected")
      |> assign(:call_active, assigns.call != nil)
      |> assign(:game_active, Map.get(assigns.game || %{}, :status) == "playing")
      |> assign(
        :file_active,
        Map.get(assigns.file_transfer || %{}, :status) in ~w(offering offer_received transferring paused)
      )
      |> assign(:max_file_size_mb, file_transfer_max_size_mb())
      |> assign(:blocked_file_extensions, file_transfer_blocked_extensions())

    ~H"""
    <div class="lobby flex h-screen flex-col bg-background text-foreground" {@rest}>
      <.lobby_ended :if={@expired or @session_closed} reason={@ended_reason} />

      <div :if={!(@expired or @session_closed)} class="flex h-full flex-col">
        <%!-- Persistent connection hook (always mounted once joined) --%>
        <div id="lobby-webrtc" phx-hook="LobbyWebRTCHook" phx-update="ignore" class="u-hidden"></div>

        <%!-- Slim status bar: identity + peer + live connection state --%>
        <.toolbar class="items-center gap-2 p-2">
          <Icons.icon_p2p class="h-4 w-4" />
          <span class="text-xs font-bold">{dgettext("lobby", "Universal Lobby")}</span>
          <span class="text-muted-foreground flex items-center gap-1 text-xs">
            <Icons.icon_status_user class="h-3 w-3" />
            {dgettext("lobby", "with %{peer}", peer: @peer_nick)}
          </span>
          <.badge variant="outline">
            <Icons.icon_webrtc class="mr-1 h-3 w-3" />{@connection_label}
          </.badge>
        </.toolbar>

        <.alert :if={@inactivity_warning} variant="destructive" class="rounded-none">
          <:icon><Icons.icon_warning class="h-4 w-4" /></:icon>
          <.alert_description>
            {dgettext("lobby", "This lobby will close soon due to inactivity.")}
          </.alert_description>
        </.alert>

        <.desktop id="lobby-desktop" persist_key="lobby" data-testid="lobby-desktop">
          <%!-- Connection telemetry & diagram — always present, cannot be closed --%>
          <.desktop_window
            id="conn"
            title={dgettext("lobby", "Connection")}
            pinned
            default_x={560}
            default_y={16}
            width={320}
            data-testid="lobby-window-conn"
          >
            <:icon><Icons.icon_webrtc class="h-4 w-4" /></:icon>
            <.p2p_connection_strip
              nickname={@nickname}
              peer_nick={@peer_nick}
              peer_online={@peer_online}
              session_status={@session_status}
              webrtc_state={@connection_label}
              file_transfer={@file_transfer}
              call={@call}
              local_info={@local_info}
              peer_info={@peer_info}
            />
            <.lobby_network_panel
              :if={@call && @stats}
              stats={@stats}
              info_open={@network_info_open}
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
            <.chat_panel messages={@messages} />
          </.desktop_window>

          <%!-- Audio/video call --%>
          <.desktop_window
            id="call"
            title={dgettext("lobby", "Call")}
            open={false}
            on_close={if @call_active, do: "end_call"}
            default_x={16}
            default_y={16}
            width={460}
            body_class="p-1"
            data-testid="lobby-window-call"
          >
            <:icon><Icons.icon_camera class="h-4 w-4" /></:icon>
            <.media_panel
              connected={@mounted}
              call={@call}
              call_layout={@call_layout}
              peer_nick={@peer_nick}
              nickname={@nickname}
              local_muted={@local_muted}
              local_camera_off={@local_camera_off}
              peer_media={@peer_media}
              devices={@devices}
            />
          </.desktop_window>

          <%!-- File transfer --%>
          <.desktop_window
            id="file"
            title={dgettext("lobby", "Files")}
            open={false}
            on_close={if @file_active, do: "ft_cancel"}
            default_x={360}
            default_y={300}
            width={320}
            body_class="p-1"
            data-testid="lobby-window-file"
          >
            <:icon><Icons.icon_file_send class="h-4 w-4" /></:icon>
            <.file_panel
              connected={@mounted}
              file_transfer={@file_transfer}
              nickname={@nickname}
              max_file_size_mb={@max_file_size_mb}
              blocked_file_extensions={@blocked_file_extensions}
            />
          </.desktop_window>

          <%!-- Games --%>
          <.desktop_window
            id="game"
            title={dgettext("lobby", "Games")}
            open={false}
            on_close={if @game_active, do: "end_game"}
            default_x={120}
            default_y={48}
            width={680}
            body_class="p-1"
            data-testid="lobby-window-game"
          >
            <:icon><Icons.icon_joystick class="h-4 w-4" /></:icon>
            <.game_panel
              connected={@mounted}
              game={@game}
              game_request={@game_request}
              game_outgoing={@game_outgoing}
              games={@games}
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
                    <.start_menu_item data-window-open="conn" label={dgettext("lobby", "Connection")}>
                      <:icon><Icons.icon_webrtc class="h-4 w-4" /></:icon>
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

              <.taskbar_button window="conn" label={dgettext("lobby", "Connection")}>
                <:icon><Icons.icon_webrtc class="h-4 w-4" /></:icon>
              </.taskbar_button>
              <.taskbar_button window="chat" label={dgettext("lobby", "Chat")}>
                <:icon><Icons.icon_chat class="h-4 w-4" /></:icon>
              </.taskbar_button>
              <.taskbar_button
                window="call"
                label={dgettext("lobby", "Call")}
                badge={if @call_active, do: @call[:duration]}
              >
                <:icon><Icons.icon_camera class="h-4 w-4" /></:icon>
              </.taskbar_button>
              <.taskbar_button
                window="file"
                label={dgettext("lobby", "Files")}
                badge={if @file_active, do: "#{@file_transfer[:percent] || 0}%"}
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

              <:tray>
                <.desktop_tray>
                  <Icons.icon_privacy
                    :if={@turn_only}
                    class="h-3 w-3"
                    data-testid="lobby-tray-privacy"
                  />
                  <span id="lobby-clock" phx-hook="ClockHook" class="tabular-nums"></span>
                </.desktop_tray>
              </:tray>
            </.taskbar>
          </:taskbar>
        </.desktop>
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

  # --- Helpers ---

  defp file_transfer_max_size_mb do
    Application.get_env(:retro_hex_chat, :file_transfer_max_size_mb, 500)
  end

  defp file_transfer_blocked_extensions do
    Application.get_env(
      :retro_hex_chat,
      :file_transfer_blocked_extensions,
      ~w(.exe .bat .cmd .com .msi .scr .pif .vbs .vbe .js .jse .wsf .wsh .ps1 .reg)
    )
  end
end
