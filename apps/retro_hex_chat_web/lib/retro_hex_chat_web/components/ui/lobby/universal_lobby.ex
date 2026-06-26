defmodule RetroHexChatWeb.Components.UI.Lobby.UniversalLobby do
  @moduledoc """
  Universal lobby master component — the complete `/lobby` session UI.

  Hosts every P2P feature concurrently over one persistent connection: a feature
  dock, self-controlled audio/video, file transfer, games, lobby chat, live
  network telemetry and the connection diagram.

  Composed entirely from primitives (window/button/toolbar/badge/alert/fieldset/
  scroll_area/input) plus the shared p2p connection diagram, file transfer and
  the lobby network panel — no bespoke widget markup. Every button carries a
  16×16 icon for Win98 visual consistency.

  The LobbyWebRTCHook, LobbyMediaHook, FileTransferHook, LobbyGameCanvasHook and
  P2PChatFormHook attach via `phx-hook` for client-side transport handling.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Toolbar
  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Alert
  import RetroHexChatWeb.Components.UI.ScrollArea
  import RetroHexChatWeb.Components.UI.Fieldset
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.P2PConnectionDiagram
  import RetroHexChatWeb.Components.UI.FileTransfer
  import RetroHexChatWeb.Components.UI.Lobby.LobbyNetworkPanel

  alias RetroHexChatWeb.Icons

  # Identity & status
  attr :nickname, :string, required: true
  attr :peer_nick, :string, required: true
  attr :peer_online, :boolean, default: false
  attr :session_status, :string, required: true
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
  attr :diagram_collapsed, :boolean, default: true

  # Media
  attr :call, :map, default: nil
  attr :call_layout, :string, default: "focus", values: ~w(focus side_by_side maximized)
  attr :local_muted, :boolean, default: false
  attr :local_camera_off, :boolean, default: false
  attr :peer_media, :map, default: %{audio: false, video: false}
  attr :devices, :map, default: nil
  attr :stats, :map, default: nil
  attr :network_collapsed, :boolean, default: false
  attr :network_info_open, :boolean, default: false

  # File transfer
  attr :file_panel_open, :boolean, default: false
  attr :file_transfer, :map, default: nil

  # Games
  attr :game, :map, default: %{status: "idle", game_id: nil, is_host: false}
  attr :game_request, :map, default: nil
  attr :game_outgoing, :boolean, default: false
  attr :game_panel_open, :boolean, default: false
  attr :games, :list, default: []

  # Chat
  attr :messages, :list, default: []

  attr :rest, :global

  @spec universal_lobby(map()) :: Phoenix.LiveView.Rendered.t()
  def universal_lobby(assigns) do
    assigns =
      assigns
      |> assign(:max_file_size_mb, file_transfer_max_size_mb())
      |> assign(:blocked_file_extensions, file_transfer_blocked_extensions())

    ~H"""
    <div class="lobby flex h-screen flex-col bg-background text-foreground" {@rest}>
      <.lobby_ended :if={@expired or @session_closed} reason={@ended_reason} />

      <div :if={!(@expired or @session_closed)} class="flex h-full flex-col">
        <%!-- Persistent connection hook (always mounted once joined) --%>
        <div id="lobby-webrtc" phx-hook="LobbyWebRTCHook" phx-update="ignore" class="u-hidden"></div>

        <%!-- Session header: title, peer, connection status, privacy & leave --%>
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
          <div class="ml-auto flex gap-2">
            <.button
              :if={@turn_configured}
              size="sm"
              variant="outline"
              phx-click="toggle_privacy_mode"
              data-testid="lobby-privacy"
            >
              <:icon><Icons.icon_privacy class="h-4 w-4" /></:icon>
              {if @turn_only,
                do: dgettext("lobby", "Privacy: ON"),
                else: dgettext("lobby", "Privacy: OFF")}
            </.button>
            <.button
              size="sm"
              variant="destructive"
              phx-click="leave_lobby"
              data-testid="lobby-leave"
            >
              <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
              {dgettext("lobby", "Leave")}
            </.button>
          </div>
        </.toolbar>

        <.alert :if={@inactivity_warning} variant="destructive" class="rounded-none">
          <:icon><Icons.icon_warning class="h-4 w-4" /></:icon>
          <.alert_description>
            {dgettext("lobby", "This lobby will close soon due to inactivity.")}
          </.alert_description>
        </.alert>

        <%!-- Connection diagram / whois --%>
        <div class="p-3 pb-0">
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
        </div>

        <.lobby_dock session_status={@session_status} call={@call} />

        <div class="flex flex-1 gap-3 overflow-hidden p-3">
          <div class="flex flex-1 flex-col gap-3 overflow-auto">
            <.media_panel
              :if={@session_status == "connected"}
              call={@call}
              call_layout={@call_layout}
              peer_nick={@peer_nick}
              nickname={@nickname}
              local_muted={@local_muted}
              local_camera_off={@local_camera_off}
              peer_media={@peer_media}
              devices={@devices}
            />

            <.lobby_network_panel
              :if={@call && @stats}
              stats={@stats}
              collapsed={@network_collapsed}
              info_open={@network_info_open}
            />

            <.file_panel
              :if={@session_status == "connected"}
              open={@file_panel_open}
              file_transfer={@file_transfer}
              nickname={@nickname}
              max_file_size_mb={@max_file_size_mb}
              blocked_file_extensions={@blocked_file_extensions}
            />

            <.game_panel
              :if={@game_panel_open}
              game={@game}
              game_request={@game_request}
              game_outgoing={@game_outgoing}
              games={@games}
              peer_nick={@peer_nick}
            />
          </div>

          <.chat_panel messages={@messages} />
        </div>
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

  # --- Feature dock ---

  attr :session_status, :string, required: true
  attr :call, :map, default: nil

  defp lobby_dock(assigns) do
    ~H"""
    <.toolbar class="flex-wrap gap-2 p-2" data-testid="lobby-dock">
      <.button
        size="sm"
        phx-click="start_call"
        phx-value-type="audio"
        disabled={@session_status != "connected" or @call != nil}
        data-testid="lobby-dock-audio"
      >
        <:icon><Icons.icon_microphone class="h-4 w-4" /></:icon>
        {dgettext("lobby", "Audio")}
      </.button>
      <.button
        size="sm"
        phx-click="start_call"
        phx-value-type="video"
        disabled={@session_status != "connected" or @call != nil}
        data-testid="lobby-dock-video"
      >
        <:icon><Icons.icon_camera class="h-4 w-4" /></:icon>
        {dgettext("lobby", "Video")}
      </.button>
      <.button
        size="sm"
        phx-click="toggle_file_panel"
        disabled={@session_status != "connected"}
        data-testid="lobby-dock-file"
      >
        <:icon><Icons.icon_file_send class="h-4 w-4" /></:icon>
        {dgettext("lobby", "File")}
      </.button>
      <.button
        size="sm"
        phx-click="toggle_game_panel"
        disabled={@session_status != "connected"}
        data-testid="lobby-dock-game"
      >
        <:icon><Icons.icon_joystick class="h-4 w-4" /></:icon>
        {dgettext("lobby", "Game")}
      </.button>
    </.toolbar>
    """
  end

  # --- Media panel ---

  attr :call, :map, default: nil
  attr :call_layout, :string, required: true
  attr :peer_nick, :string, required: true
  attr :nickname, :string, required: true
  attr :local_muted, :boolean, required: true
  attr :local_camera_off, :boolean, required: true
  attr :peer_media, :map, required: true
  attr :devices, :map, default: nil

  defp media_panel(assigns) do
    ~H"""
    <section
      id="lobby-media"
      phx-hook="LobbyMediaHook"
      class="shadow-retro-raised bg-accent p-2"
      data-testid="lobby-media-panel"
    >
      <div :if={@call} class={"lobby-media lobby-media--#{@call_layout}"}>
        <div class="relative">
          <div class="lobby-media__nameplate">
            <Icons.icon_camera class="h-3 w-3" />
            <span>{@peer_nick}</span>
          </div>
          <video
            id="lobby-remote-video"
            class={["w-full bg-black", @call[:peer_camera_off] && "u-hidden"]}
            autoplay
            playsinline
          >
          </video>
          <div
            :if={@call[:peer_camera_off]}
            data-testid="lobby-peer-camera-off"
            class="text-muted-foreground p-4 text-center text-xs"
          >
            <Icons.icon_camera_off class="mx-auto mb-1 h-4 w-4" />
            {dgettext("lobby", "%{peer}'s camera is off", peer: @peer_nick)}
          </div>
          <video
            id="lobby-local-video"
            class="absolute bottom-2 right-2 w-24 bg-black"
            autoplay
            playsinline
            muted
          >
          </video>
          <audio id="lobby-remote-audio" autoplay></audio>
        </div>

        <p
          :if={@call[:peer_muted]}
          data-testid="lobby-peer-muted"
          class="flex items-center justify-center gap-1 text-center text-xs font-bold"
        >
          <Icons.icon_mute class="h-3 w-3" />
          {dgettext("lobby", "%{peer} is muted", peer: @peer_nick)}
        </p>

        <%!-- Media controls --%>
        <.toolbar class="mt-2 flex-wrap items-center gap-1">
          <.toolbar_button
            label={if @local_muted, do: dgettext("lobby", "Unmute"), else: dgettext("lobby", "Mute")}
            active={@local_muted}
            variant="compact"
            data-lobby-media-action="mute"
          >
            <Icons.icon_mute :if={@local_muted} class="h-4 w-4" />
            <Icons.icon_microphone :if={!@local_muted} class="h-4 w-4" />
          </.toolbar_button>
          <.toolbar_button
            :if={@call[:type] == "video"}
            label={
              if @local_camera_off,
                do: dgettext("lobby", "Camera On"),
                else: dgettext("lobby", "Camera Off")
            }
            active={@local_camera_off}
            variant="compact"
            data-lobby-media-action="camera"
          >
            <Icons.icon_camera_off :if={@local_camera_off} class="h-4 w-4" />
            <Icons.icon_camera :if={!@local_camera_off} class="h-4 w-4" />
          </.toolbar_button>
          <.toolbar_button
            :if={@call[:type] == "audio"}
            label={dgettext("lobby", "Add Video")}
            variant="compact"
            data-lobby-media-action="upgrade"
          >
            <Icons.icon_upgrade_video class="h-4 w-4" />
          </.toolbar_button>
          <.toolbar_button
            :if={@call[:type] == "video"}
            label={dgettext("lobby", "Picture-in-Picture")}
            variant="compact"
            data-lobby-media-action="pip"
          >
            <Icons.icon_pip class="h-4 w-4" />
          </.toolbar_button>
          <.toolbar_button
            label={dgettext("lobby", "Devices")}
            variant="compact"
            data-lobby-media-action="device-settings"
          >
            <Icons.icon_devices class="h-4 w-4" />
          </.toolbar_button>
          <.toolbar_separator variant="compact" />
          <.toolbar_button
            label={dgettext("lobby", "End call")}
            variant="compact"
            class="text-error"
            data-lobby-media-action="end-call"
          >
            <Icons.icon_phone_end class="h-4 w-4" />
          </.toolbar_button>
          <span class="text-muted-foreground ml-auto text-xs">{@call[:duration]}</span>
        </.toolbar>

        <%!-- Layout switch (video only) --%>
        <.toolbar :if={@call[:type] == "video"} variant="compact" class="mt-1 gap-1">
          <.toolbar_button
            label={dgettext("lobby", "Focus")}
            active={@call_layout == "focus"}
            variant="compact"
            phx-click="set_call_layout"
            phx-value-layout="focus"
          >
            <Icons.icon_layout_focus class="h-4 w-4" />
          </.toolbar_button>
          <.toolbar_button
            label={dgettext("lobby", "Side by side")}
            active={@call_layout == "side_by_side"}
            variant="compact"
            phx-click="set_call_layout"
            phx-value-layout="side_by_side"
          >
            <Icons.icon_layout_side_by_side class="h-4 w-4" />
          </.toolbar_button>
          <.toolbar_button
            label={dgettext("lobby", "Maximize")}
            active={@call_layout == "maximized"}
            variant="compact"
            phx-click="set_call_layout"
            phx-value-layout="maximized"
          >
            <Icons.icon_layout_maximize class="h-4 w-4" />
          </.toolbar_button>
        </.toolbar>

        <%!-- Quality presets --%>
        <div
          :if={@call[:quality_label]}
          class="text-muted-foreground mt-1 flex items-center gap-1 text-xs"
        >
          <span>{dgettext("lobby", "Quality: %{q}", q: @call[:quality_label])}</span>
          <.toolbar_button
            label={dgettext("lobby", "High")}
            variant="compact"
            phx-click="media_select_preset"
            phx-value-preset="high"
          >
            <Icons.icon_quality_high class="h-4 w-4" />
          </.toolbar_button>
          <.toolbar_button
            label={dgettext("lobby", "Medium")}
            variant="compact"
            phx-click="media_select_preset"
            phx-value-preset="medium"
          >
            <Icons.icon_quality_medium class="h-4 w-4" />
          </.toolbar_button>
          <.toolbar_button
            label={dgettext("lobby", "Low")}
            variant="compact"
            phx-click="media_select_preset"
            phx-value-preset="low"
          >
            <Icons.icon_quality_low class="h-4 w-4" />
          </.toolbar_button>
        </div>

        <%!-- Device selectors: native selects read by LobbyMediaHook via data-device-kind --%>
        <div :if={@devices} class="mt-1 flex flex-wrap gap-2" data-testid="lobby-devices">
          <select
            :for={kind <- ~w(audioinput videoinput audiooutput)}
            :if={@devices[kind] not in [nil, []]}
            data-device-kind={kind}
            class="shadow-retro-sunken bg-input text-xs"
          >
            <option :for={d <- @devices[kind]} value={d["id"]}>{d["label"]}</option>
          </select>
        </div>
      </div>

      <p :if={!@call} class="text-muted-foreground flex items-center gap-2 text-xs">
        <Icons.icon_camera class="h-4 w-4 shrink-0" />
        {dgettext(
          "lobby",
          "Start audio or video from the dock. The peer can do the same independently."
        )}
        <span :if={@peer_media.audio or @peer_media.video} class="font-bold">
          {dgettext("lobby", "%{peer} is sharing media.", peer: @peer_nick)}
        </span>
      </p>
    </section>
    """
  end

  # --- File transfer panel ---

  attr :open, :boolean, required: true
  attr :file_transfer, :map, default: nil
  attr :nickname, :string, required: true
  attr :max_file_size_mb, :integer, required: true
  attr :blocked_file_extensions, :list, required: true

  defp file_panel(assigns) do
    ~H"""
    <section
      id="lobby-file-transfer"
      phx-hook="FileTransferHook"
      data-webrtc-id="lobby-webrtc"
      data-max-size-mb={@max_file_size_mb}
      data-blocked-extensions={Enum.join(@blocked_file_extensions, ",")}
      class={["shadow-retro-raised bg-accent p-3", !@open && "u-hidden"]}
      data-testid="lobby-file-panel"
    >
      <p class="mb-2 flex items-center gap-1 text-xs font-bold">
        <Icons.icon_file_send class="h-4 w-4" />{dgettext("lobby", "File transfer")}
      </p>
      <input type="file" id="lobby-file-input" class="file-transfer-input u-hidden" />

      <div
        :if={
          @file_transfer && @file_transfer[:status] in ["ready", "validation_error"] &&
            !@file_transfer[:file_name]
        }
        class="shadow-retro-field bg-white p-4 text-center text-xs"
      >
        <Icons.icon_file_send class="mx-auto mb-2 h-6 w-6" />
        <p
          :if={@file_transfer[:validation_error]}
          class="text-error mb-2 font-bold"
          data-testid="lobby-ft-validation-error"
        >
          {@file_transfer[:validation_error]}
        </p>
        <p class="mb-2">
          {dgettext(
            "lobby",
            "Drop a file here, or browse. Transfers run alongside your call and game."
          )}
        </p>
        <p class="text-muted-foreground mb-2">
          {dgettext("lobby", "Max: %{size} MB", size: @max_file_size_mb)}
        </p>
        <label for="lobby-file-input">
          <.button type="button" size="sm">
            <:icon><Icons.icon_choose_file class="h-4 w-4" /></:icon>
            {dgettext("lobby", "Browse files")}
          </.button>
        </label>
      </div>

      <.file_transfer
        :if={@file_transfer && @file_transfer[:file_name]}
        file_name={@file_transfer[:file_name]}
        progress={@file_transfer[:percent] || 0}
        speed={@file_transfer[:speed]}
        formatted_size={@file_transfer[:formatted_size]}
        state={@file_transfer[:status] || "ready"}
        direction={ft_direction(@file_transfer, @nickname)}
        cancelled_by={@file_transfer[:cancelled_by]}
        on_cancel="ft_cancel"
        on_accept="ft_accept_offer"
      />
    </section>
    """
  end

  # --- Game panel ---

  attr :game, :map, required: true
  attr :game_request, :map, default: nil
  attr :game_outgoing, :boolean, required: true
  attr :games, :list, required: true
  attr :peer_nick, :string, required: true

  defp game_panel(assigns) do
    ~H"""
    <section class="shadow-retro-raised bg-accent p-3" data-testid="lobby-game-panel">
      <div :if={@game.status == "playing"}>
        <div class="mb-2 flex items-center justify-between">
          <p class="flex items-center gap-1 text-xs font-bold">
            <Icons.icon_joystick class="h-4 w-4" />{dgettext("lobby", "Game in progress")}
          </p>
          <.button size="sm" variant="outline" phx-click="end_game">
            <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
            {dgettext("lobby", "End game")}
          </.button>
        </div>
        <div
          id="lobby-game-canvas"
          phx-hook="LobbyGameCanvasHook"
          phx-update="ignore"
          data-game-id={@game.game_id}
          data-is-host={to_string(@game.is_host)}
          class="flex justify-center"
        >
          <canvas width="640" height="480" class="bg-black"></canvas>
        </div>
      </div>

      <div :if={@game.status != "playing"}>
        <div :if={@game_request && !@game_outgoing} class="mb-3" data-testid="lobby-game-consent">
          <p class="flex items-center gap-1 text-xs">
            <Icons.game_icon game_id={@game_request.game_id} class="h-4 w-4" />
            {dgettext("lobby", "%{peer} wants to play %{game}",
              peer: @game_request.proposer_nick,
              game: @game_request.game_id
            )}
          </p>
          <div class="mt-1 flex gap-2">
            <.button size="sm" phx-click="respond_game" phx-value-accepted="true">
              <:icon><Icons.icon_checkmark class="h-4 w-4" /></:icon>
              {dgettext("lobby", "Accept")}
            </.button>
            <.button size="sm" variant="outline" phx-click="respond_game" phx-value-accepted="false">
              <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
              {dgettext("lobby", "Decline")}
            </.button>
          </div>
        </div>

        <p
          :if={@game_request && @game_outgoing}
          class="text-muted-foreground mb-3 flex items-center gap-1 text-xs"
        >
          <Icons.icon_clock class="h-4 w-4 animate-spin" />
          {dgettext("lobby", "Waiting for %{peer} to accept...", peer: @peer_nick)}
        </p>

        <div class="grid grid-cols-2 gap-2 sm:grid-cols-3">
          <button
            :for={game <- @games}
            type="button"
            phx-click="propose_game"
            phx-value-game_id={game.id}
            disabled={@game_request != nil}
            class="shadow-retro-raised bg-secondary flex items-center gap-2 p-2 text-left text-xs disabled:opacity-50"
            data-testid={"lobby-game-#{game.id}"}
          >
            <Icons.game_icon game_id={game.id} class="h-8 w-8 shrink-0" />
            <span class="min-w-0">
              <span class="block truncate font-bold">{game.name}</span>
              <span class="text-muted-foreground block truncate">{game.tagline}</span>
            </span>
          </button>
        </div>
      </div>
    </section>
    """
  end

  # --- Chat panel ---

  attr :messages, :list, required: true

  defp chat_panel(assigns) do
    ~H"""
    <.retro_fieldset
      legend={dgettext("lobby", "Chat")}
      class="flex w-72 flex-col"
      data-testid="lobby-chat"
    >
      <.scroll_area class="shadow-retro-field flex-1 space-y-1 bg-white p-2" id="lobby-messages">
        <p :for={msg <- @messages} class="text-xs">
          <span :if={msg.type == "system"} class="text-muted-foreground italic">{msg.content}</span>
          <span :if={msg.type != "system"}>
            <span class="font-bold">{msg.sender_nick}:</span>
            {msg.content}
          </span>
        </p>
      </.scroll_area>
      <form
        phx-submit="send_message"
        phx-hook="P2PChatFormHook"
        id="lobby-chat-form"
        class="mt-2 flex gap-1"
      >
        <.input
          type="text"
          name="content"
          autocomplete="off"
          maxlength="500"
          placeholder={dgettext("lobby", "Type a message")}
          class="flex-1 text-xs"
        />
        <.button type="submit" size="sm">
          <:icon><Icons.icon_send class="h-4 w-4" /></:icon>
          {dgettext("lobby", "Send")}
        </.button>
      </form>
    </.retro_fieldset>
    """
  end

  # --- Helpers ---

  @spec ft_direction(map(), String.t()) :: String.t()
  defp ft_direction(ft, nickname) do
    if Map.get(ft, :sender_nick) == nickname, do: "sending", else: "receiving"
  end

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
