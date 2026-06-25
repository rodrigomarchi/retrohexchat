defmodule RetroHexChatWeb.Components.UI.P2PLobby do
  @moduledoc """
  P2P lobby master component — the complete P2P session UI.

  Contains the full P2P flow: connection diagram, media calls (audio/video),
  file transfer, consent banners, lobby chat, session toolbar, and status.

  Composed from window + button + progress + toolbar + input + file_transfer primitives.
  MediaHook and FileTransferHook attach via phx-hook for client-side media/file handling.

  ## Usage

      <.p2p_lobby
        peer="alice"
        state="active"
        nickname="you"
        local_info=%{browser: "Chrome 145.0", os: "macOS 10.15"}
        peer_info=%{browser: "Firefox 148.0", os: "Linux"}
        call=%{type: "video"}
        messages={[]}
        on_connect="p2p_connect"
        on_cancel="close_session"
        on_disconnect="close_session"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Progress
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Toolbar
  import RetroHexChatWeb.Components.UI.Alert
  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.ScrollArea
  import RetroHexChatWeb.Components.UI.Fieldset
  import RetroHexChatWeb.Components.UI.P2PConnectionDiagram
  import RetroHexChatWeb.Components.UI.FileTransfer

  alias RetroHexChatWeb.Icons

  @doc "Renders the complete P2P session UI."
  # Identity
  attr :peer, :string, required: true
  attr :nickname, :string, default: "You", doc: "Local user nickname"
  attr :peer_online, :boolean, default: false, doc: "Whether the peer is currently online"
  attr :local_info, :map, default: %{}, doc: "Local user whois info (browser, os, screen, etc.)"
  attr :peer_info, :map, default: %{}, doc: "Peer whois info"

  # State
  attr :state, :string, default: "pending", values: ~w(pending lobby connecting active failed)
  attr :webrtc_state, :string, default: nil, doc: "WebRTC connection state label"
  attr :retry_attempt, :integer, default: nil, doc: "Current retry attempt number"

  attr :diagram_collapsed, :boolean,
    default: true,
    doc: "Whether the connection diagram is compact"

  # Media call
  attr :call, :map, default: nil, doc: "Active call state map"
  attr :call_layout, :string, default: "focus", values: ~w(focus side_by_side maximized)
  attr :local_muted, :boolean, default: false, doc: "Local microphone muted"
  attr :local_camera_off, :boolean, default: false, doc: "Local camera disabled"

  # File transfer
  attr :file_transfer, :map, default: nil, doc: "File transfer state map"

  # Messages & consent
  attr :messages, :list, default: [], doc: "Lobby chat messages"
  attr :action_request, :map, default: nil, doc: "Pending action request for consent"

  attr :user_id, :any,
    default: nil,
    doc: "Current user id, to distinguish requester from recipient"

  # Session controls
  attr :turn_configured, :boolean, default: false, doc: "Whether TURN server is configured"
  attr :turn_only, :boolean, default: false, doc: "Privacy mode (TURN-only relay)"
  attr :inactivity_warning, :boolean, default: false, doc: "Show inactivity warning"

  # Callbacks
  attr :on_cancel, :any, default: nil, doc: "Cancel button callback"

  # Styling
  attr :class, :string, default: nil
  attr :rest, :global

  @spec p2p_lobby(map()) :: Phoenix.LiveView.Rendered.t()
  def p2p_lobby(assigns) do
    assigns =
      if assigns.peer_online == false and assigns.state in ["lobby", "connecting", "active"] do
        assign(assigns, :peer_online, true)
      else
        assigns
      end

    assigns =
      assigns
      |> assign(:max_file_size_mb, file_transfer_max_size_mb())
      |> assign(:blocked_file_extensions, file_transfer_blocked_extensions())
      |> assign(:activity_kind, activity_kind(assigns))

    ~H"""
    <.window
      class={
        classes([
          "p2p-lobby-window w-full",
          @activity_kind != "idle" && "p2p-lobby-window--active",
          @call && "p2p-lobby-window--call",
          @call && "p2p-lobby-window--call-#{@call_layout}",
          @file_transfer && "p2p-lobby-window--file",
          @class
        ])
      }
      data-testid="p2p-lobby"
      {@rest}
    >
      <.window_title_bar title={dgettext("p2p", "P2P Connection")} controls={[:close]}>
        <:icon><Icons.icon_p2p class="w-4 h-4" /></:icon>
      </.window_title_bar>

      <.window_body class="p2p-lobby__body p-retro-8 space-y-retro-8">
        <%!-- Connection diagram with peer info --%>
        <div class="p2p-lobby__diagram-panel">
          <div class="p2p-lobby__diagram-header">
            <span class="p2p-lobby__diagram-title">{dgettext("p2p", "Connection Diagram")}</span>
            <.toolbar variant="compact" class="gap-[1px]">
              <.toolbar_button
                label={
                  if @diagram_collapsed,
                    do: dgettext("p2p", "Expand diagram"),
                    else: dgettext("p2p", "Collapse diagram")
                }
                variant="compact"
                phx-click="toggle_diagram"
                data-testid="p2p-diagram-toggle"
              >
                <Icons.icon_win_restore :if={@diagram_collapsed} class="w-4 h-4" />
                <Icons.icon_win_minimize :if={!@diagram_collapsed} class="w-4 h-4" />
              </.toolbar_button>
            </.toolbar>
          </div>

          <.p2p_connection_strip
            :if={@diagram_collapsed}
            nickname={@nickname}
            peer_nick={@peer}
            peer_online={@peer_online}
            session_status={@state}
            webrtc_state={@webrtc_state}
            retry_attempt={@retry_attempt}
            file_transfer={@file_transfer}
            call={@call}
            local_info={@local_info}
            peer_info={@peer_info}
          />

          <.p2p_connection_diagram
            :if={!@diagram_collapsed}
            nickname={@nickname}
            peer_nick={@peer}
            peer_online={@peer_online}
            session_status={@state}
            webrtc_state={@webrtc_state}
            retry_attempt={@retry_attempt}
            file_transfer={@file_transfer}
            call={@call}
            local_info={@local_info}
            peer_info={@peer_info}
          />
        </div>

        <%!-- Progress bar when connecting --%>
        <.progress :if={@state == "connecting"} value={50} class="h-3" />

        <%!-- Cancel button during connecting --%>
        <div :if={@state == "connecting"} class="flex gap-retro-4 justify-end">
          <.button
            variant="destructive"
            phx-click={@on_cancel}
            data-testid="p2p-lobby-cancel"
          >
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {dgettext("p2p", "Cancel")}
          </.button>
        </div>

        <%!-- Chat area: messages + input --%>
        <.p2p_chat_panel :if={!@call && !@file_transfer} messages={@messages} />

        <%!-- Action request consent banner --%>
        <.p2p_consent_banner
          :if={
            @action_request && @action_request[:status] != "accepted" &&
              @action_request[:status] != "rejected"
          }
          action_request={@action_request}
          peer={@peer}
          is_requester={@user_id != nil && @action_request[:requester_id] == @user_id}
        />

        <%!-- Media call area (MediaHook handles audio/video streams and controls) --%>
        <div
          :if={@call}
          class={"p2p-lobby__activity p2p-lobby__activity--call p2p-lobby__activity--#{@call_layout}"}
        >
          <div
            id="media-call"
            phx-hook="MediaHook"
            class={
              classes([
                "p2p-media-call shadow-retro-raised bg-surface",
                "p2p-media-call--#{@call_layout}",
                @call[:type] == "video" && "p2p-media-call--video"
              ])
            }
            data-testid="media-call"
          >
            <%!-- Video area --%>
            <div :if={@call[:type] == "video"} class="p2p-media-call__video-stage">
              <div class="p2p-media-call__remote-panel">
                <div class="p2p-media-call__nameplate">
                  <Icons.icon_camera class="w-3 h-3" />
                  <span>{@peer}</span>
                </div>
                <video
                  id="remote-video"
                  class={[
                    "p2p-media-call__remote-video",
                    @call[:peer_camera_off] && "hidden"
                  ]}
                  autoplay
                  playsinline
                >
                </video>
                <div
                  :if={@call[:peer_camera_off]}
                  data-testid="media-peer-camera-off-indicator"
                  class="p2p-media-call__camera-off"
                >
                  <span>{dgettext("p2p", "Camera off")}</span>
                </div>
              </div>
              <div class="p2p-media-call__local-panel">
                <div class="p2p-media-call__nameplate">
                  <Icons.icon_camera class="w-3 h-3" />
                  <span>{dgettext("p2p", "%{nickname} (you)", nickname: @nickname)}</span>
                </div>
                <video
                  id="local-video"
                  class="p2p-media-call__local-video"
                  autoplay
                  playsinline
                  muted
                >
                </video>
              </div>
            </div>
            <%!-- Audio element (always present for audio streams) --%>
            <audio id="remote-audio" autoplay></audio>
            <div
              :if={@call[:peer_muted]}
              data-testid="media-peer-muted-indicator"
              class="px-2 pt-2 text-center text-xs font-bold"
            >
              {dgettext("p2p", "Peer muted")}
            </div>
            <%!-- Media controls toolbar --%>
            <.toolbar class="gap-1 p-2 justify-center">
              <.toolbar_button
                label={if @local_muted, do: dgettext("p2p", "Unmute"), else: dgettext("p2p", "Mute")}
                active={@local_muted}
                variant="compact"
                data-media-action="mute"
                data-testid="media-controls-mute"
              >
                <Icons.icon_mute :if={@local_muted} class="w-4 h-4" />
                <Icons.icon_microphone :if={!@local_muted} class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_button
                :if={@call[:type] == "video"}
                label={
                  if @local_camera_off,
                    do: dgettext("p2p", "Camera On"),
                    else: dgettext("p2p", "Camera Off")
                }
                active={@local_camera_off}
                variant="compact"
                data-media-action="camera"
                data-testid="media-controls-camera"
              >
                <Icons.icon_camera_off :if={@local_camera_off} class="w-4 h-4" />
                <Icons.icon_camera :if={!@local_camera_off} class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_button
                :if={@call[:type] == "audio"}
                label={dgettext("p2p", "Add Video")}
                variant="compact"
                data-media-action="upgrade"
              >
                <Icons.icon_upgrade_video class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_button
                :if={@call[:type] == "video"}
                label={dgettext("p2p", "Picture-in-Picture")}
                variant="compact"
                data-media-action="pip"
              >
                <Icons.icon_pip class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_separator :if={@call[:type] == "video"} variant="compact" />
              <.toolbar_button
                :if={@call[:type] == "video"}
                label={dgettext("p2p", "Focus view")}
                active={@call_layout == "focus"}
                variant="compact"
                phx-click="set_call_layout"
                phx-value-layout="focus"
                data-testid="media-layout-focus"
              >
                <Icons.icon_layout_focus class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_button
                :if={@call[:type] == "video"}
                label={dgettext("p2p", "Side-by-side view")}
                active={@call_layout == "side_by_side"}
                variant="compact"
                phx-click="set_call_layout"
                phx-value-layout="side_by_side"
                data-testid="media-layout-side-by-side"
              >
                <Icons.icon_layout_side_by_side class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_button
                :if={@call[:type] == "video"}
                label={dgettext("p2p", "Maximize video")}
                active={@call_layout == "maximized"}
                variant="compact"
                phx-click="set_call_layout"
                phx-value-layout="maximized"
                data-testid="media-layout-maximized"
              >
                <Icons.icon_layout_maximize class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_button
                label={dgettext("p2p", "Devices")}
                variant="compact"
                data-media-action="device-settings"
              >
                <Icons.icon_devices class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_separator variant="compact" />
              <.toolbar_button
                label={dgettext("p2p", "End Call")}
                variant="compact"
                data-media-action="end-call"
                data-testid="media-controls-end-call"
                class="text-error"
              >
                <Icons.icon_phone_end class="w-4 h-4" />
              </.toolbar_button>
              <span :if={@call[:duration]} class="text-xs text-muted-foreground ml-2">
                {@call[:duration]}
              </span>
            </.toolbar>
            <%!-- Video upgrade request/response --%>
            <div
              :if={@call[:upgrade_pending]}
              class="flex items-center gap-2 p-2 text-xs bg-accent"
            >
              <Icons.icon_upgrade_video class="w-3 h-3" />
              <span class="flex-1">{dgettext("p2p", "%{peer} wants to add video", peer: @peer)}</span>
              <.button
                size="sm"
                variant="default"
                phx-click="media_respond_upgrade"
                phx-value-accepted="true"
              >
                <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
                {dgettext("p2p", "Accept")}
              </.button>
              <.button
                size="sm"
                variant="outline"
                phx-click="media_respond_upgrade"
                phx-value-accepted="false"
              >
                <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
                {dgettext("p2p", "Decline")}
              </.button>
            </div>
            <%!-- Quality presets --%>
            <div
              :if={@call[:quality_label]}
              class="flex items-center gap-2 p-2 text-xs text-muted-foreground"
            >
              <span>{dgettext("p2p", "Quality: %{quality}", quality: @call[:quality_label])}</span>
              <.toolbar_button
                label={dgettext("p2p", "High")}
                variant="compact"
                phx-click="media_select_preset"
                phx-value-preset="high"
              >
                <Icons.icon_quality_high class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_button
                label={dgettext("p2p", "Medium")}
                variant="compact"
                phx-click="media_select_preset"
                phx-value-preset="medium"
              >
                <Icons.icon_quality_medium class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_button
                label={dgettext("p2p", "Low")}
                variant="compact"
                phx-click="media_select_preset"
                phx-value-preset="low"
              >
                <Icons.icon_quality_low class="w-4 h-4" />
              </.toolbar_button>
            </div>
          </div>
          <div class="p2p-lobby__activity-side">
            <.p2p_chat_panel messages={@messages} />
          </div>
        </div>

        <%!-- File transfer area (FileTransferHook handles DataChannel and file I/O) --%>
        <div :if={@file_transfer} class="p2p-lobby__activity p2p-lobby__activity--file">
          <div
            id="p2p-file-transfer"
            phx-hook="FileTransferHook"
            class="p2p-lobby__file-panel"
            data-testid="file-transfer-hook"
            data-max-size-mb={@max_file_size_mb}
            data-blocked-extensions={Enum.join(@blocked_file_extensions, ",")}
          >
            <input type="file" id="p2p-file-input" class="file-transfer-input hidden" />
            <%!-- File selection (ready state) --%>
            <div
              :if={
                @file_transfer[:status] in ["ready", "validation_error"] &&
                  !@file_transfer[:file_name]
              }
              class="p2p-lobby__file-drop shadow-retro-field bg-white p-4 text-center text-xs"
            >
              <Icons.icon_file_send class="w-6 h-6 mx-auto mb-2" />
              <p
                :if={@file_transfer[:validation_error]}
                data-testid="file-transfer-validation-error"
                class="text-error font-bold mb-2"
              >
                {@file_transfer[:validation_error]}
              </p>
              <p class="mb-2">{dgettext("p2p", "Drag a file here or click to browse")}</p>
              <p class="text-muted-foreground mb-2">
                {dgettext("p2p", "Max: %{size} MB", size: @max_file_size_mb)}
              </p>
              <label for="p2p-file-input">
                <.button type="button" size="sm">
                  <:icon><Icons.icon_choose_file class="w-4 h-4" /></:icon>
                  {dgettext("p2p", "Browse Files")}
                </.button>
              </label>
            </div>
            <%!-- File transfer progress/status display --%>
            <.file_transfer
              :if={@file_transfer[:file_name]}
              file_name={@file_transfer[:file_name] || dgettext("p2p", "unknown")}
              progress={@file_transfer[:percent] || 0}
              speed={@file_transfer[:speed]}
              formatted_size={@file_transfer[:formatted_size]}
              state={@file_transfer[:status] || "ready"}
              direction={ft_direction(@file_transfer, @nickname)}
              cancelled_by={@file_transfer[:cancelled_by]}
              on_cancel="ft_cancel"
              on_accept="ft_accept_offer"
            />
          </div>
          <div class="p2p-lobby__activity-side">
            <.p2p_chat_panel messages={@messages} />
          </div>
        </div>

        <%!-- Session actions toolbar (visible when not connecting and no active call/transfer) --%>
        <div
          :if={@state != "connecting" && !@call && !@file_transfer}
          class="flex flex-wrap gap-2 justify-end"
        >
          <.button
            :if={@state in ["pending", "lobby", "active", "failed"]}
            size="sm"
            variant="outline"
            phx-click="close_session"
          >
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {dgettext("p2p", "Close Session")}
          </.button>
          <.button
            :if={@state in ["pending", "lobby"] && @turn_configured}
            size="sm"
            variant="outline"
            phx-click="toggle_privacy_mode"
          >
            <:icon><Icons.icon_privacy class="w-4 h-4" /></:icon>
            {if @turn_only, do: dgettext("p2p", "Privacy: ON"), else: dgettext("p2p", "Privacy: OFF")}
          </.button>
          <.button
            :if={@state == "lobby"}
            size="sm"
            phx-click="request_action"
            phx-value-action_type="audio_call"
          >
            <:icon><Icons.icon_microphone class="w-4 h-4" /></:icon>
            {dgettext("p2p", "Audio Call")}
          </.button>
          <.button
            :if={@state == "lobby"}
            size="sm"
            phx-click="request_action"
            phx-value-action_type="video_call"
          >
            <:icon><Icons.icon_camera class="w-4 h-4" /></:icon>
            {dgettext("p2p", "Video Call")}
          </.button>
          <.button
            :if={@state == "lobby"}
            size="sm"
            phx-click="request_action"
            phx-value-action_type="file_transfer"
          >
            <:icon><Icons.icon_file_send class="w-4 h-4" /></:icon>
            {dgettext("p2p", "Send File")}
          </.button>
        </div>

        <%!-- Connection status --%>
        <.badge :if={@webrtc_state} variant="outline">
          <Icons.icon_webrtc class="w-3 h-3 mr-1" /> {dgettext("p2p", "WebRTC: %{state}",
            state: @webrtc_state
          )}
        </.badge>

        <%!-- Inactivity warning --%>
        <.alert :if={@inactivity_warning} variant="destructive">
          <:icon><Icons.icon_warning class="w-4 h-4" /></:icon>
          <.alert_description>
            {dgettext("p2p", "Session will be closed due to inactivity soon.")}
          </.alert_description>
        </.alert>
      </.window_body>
    </.window>
    """
  end

  attr :messages, :list, required: true

  @spec p2p_chat_panel(map()) :: Phoenix.LiveView.Rendered.t()
  defp p2p_chat_panel(assigns) do
    ~H"""
    <.retro_fieldset
      legend={dgettext("p2p", "Chat")}
      class="p2p-lobby__chat"
      data-testid="p2p-chat-panel"
    >
      <.scroll_area class="p2p-lobby__chat-log shadow-retro-field bg-white p-2">
        <div :if={@messages == []} class="text-xs text-muted-foreground italic py-1">
          {dgettext("p2p", "No messages yet.")}
        </div>
        <div :for={msg <- @messages} class="text-xs py-[2px]">
          <span :if={msg.type != "system"} class="font-bold">{msg.sender_nick}: </span>
          <span :if={msg.type == "system"} class="text-muted-foreground italic">* </span>
          <span>{msg.content}</span>
        </div>
      </.scroll_area>
      <form
        id="p2p-chat-form"
        phx-hook="P2PChatFormHook"
        phx-submit="send_lobby_message"
        class="flex gap-2 mt-1"
      >
        <.input
          type="text"
          name="content"
          placeholder={dgettext("p2p", "Type a message...")}
          autocomplete="off"
          class="flex-1 h-8 text-xs py-1 px-2"
        />
        <.button type="submit" size="sm">
          <:icon><Icons.icon_send class="w-4 h-4" /></:icon>
          {dgettext("p2p", "Send")}
        </.button>
      </form>
    </.retro_fieldset>
    """
  end

  @doc false
  attr :action_request, :map, required: true
  attr :peer, :string, default: nil, doc: "Peer nickname, shown while waiting for a response"

  attr :is_requester, :boolean,
    default: false,
    doc: "Whether the current user sent the request (waits) vs received it (responds)"

  @spec p2p_consent_banner(map()) :: Phoenix.LiveView.Rendered.t()
  defp p2p_consent_banner(assigns) do
    ~H"""
    <div class="shadow-retro-raised bg-accent p-3">
      <p class="text-xs font-bold mb-2">
        {dgettext("p2p", "Action Request: %{action}",
          action: action_request_label(Map.get(@action_request, :action_type, "unknown"))
        )}
      </p>
      <p
        :if={@is_requester}
        class="text-xs text-muted-foreground italic"
        data-testid="p2p-consent-waiting"
      >
        {dgettext("p2p", "Waiting for %{peer} to respond...", peer: @peer)}
      </p>
      <div :if={!@is_requester} class="flex gap-2 justify-end" data-testid="p2p-consent-actions">
        <.button size="sm" phx-click="respond_action" phx-value-accepted="true">
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          {dgettext("p2p", "Accept")}
        </.button>
        <.button size="sm" variant="outline" phx-click="respond_action" phx-value-accepted="false">
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          {dgettext("p2p", "Decline")}
        </.button>
      </div>
    </div>
    """
  end

  @spec ft_direction(map(), String.t()) :: String.t()
  defp ft_direction(ft, nickname) do
    if Map.get(ft, :sender_nick) == nickname, do: "sending", else: "receiving"
  end

  defp activity_kind(%{call: call}) when is_map(call), do: "call"
  defp activity_kind(%{file_transfer: file_transfer}) when is_map(file_transfer), do: "file"
  defp activity_kind(_assigns), do: "idle"

  defp action_request_label("audio_call"), do: dgettext("p2p", "Audio Call")
  defp action_request_label("video_call"), do: dgettext("p2p", "Video Call")
  defp action_request_label("file_transfer"), do: dgettext("p2p", "File Transfer")
  defp action_request_label(_), do: dgettext("p2p", "unknown")

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
