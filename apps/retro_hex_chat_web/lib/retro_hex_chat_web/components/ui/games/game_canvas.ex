defmodule RetroHexChatWeb.Components.UI.GameCanvas do
  @moduledoc """
  Game canvas container component for the showcase design system.

  Composed from window + button primitives.
  Wraps a game session with a Win98-style window, canvas placeholder,
  player labels, and an End Game control.

  ## Usage

      <.game_canvas
        game_id="game-abc123"
        game_name="Tic-Tac-Toe"
        nickname="alice"
        peer_nick="bob"
        role={:creator}
        on_end_game="end_game"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Toolbar

  alias RetroHexChatWeb.Icons

  @doc "Renders the game canvas container."
  attr :game_id, :string, required: true
  attr :game_name, :string, required: true
  attr :nickname, :string, required: true
  attr :peer_nick, :string, required: true
  attr :role, :atom, default: :peer, values: [:creator, :peer]
  attr :on_end_game, :any, default: nil
  attr :on_start_media, :any, default: nil
  attr :on_set_media_layout, :any, default: nil
  attr :game_call, :map, default: nil
  attr :game_call_layout, :string, default: "focus"
  attr :local_muted, :boolean, default: false
  attr :local_camera_off, :boolean, default: false
  attr :media_error, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec game_canvas(map()) :: Phoenix.LiveView.Rendered.t()
  def game_canvas(assigns) do
    ~H"""
    <.window
      class={
        classes([
          "w-full",
          if(@game_call && @game_call[:type] == "video", do: "max-w-[760px]", else: "max-w-[440px]"),
          @class
        ])
      }
      data-testid="game-canvas"
      data-game-id={@game_id}
      data-is-host={to_string(@role == :creator)}
      {@rest}
    >
      <.window_title_bar
        title={
          dgettext("games", "%{game} — %{nickname} vs %{peer}",
            game: @game_name,
            nickname: @nickname,
            peer: @peer_nick
          )
        }
        controls={[:minimize, :close]}
      >
        <:icon><Icons.icon_joystick class="w-4 h-4" /></:icon>
      </.window_title_bar>

      <.window_body class="p-retro-8 space-y-retro-8">
        <%!-- Canvas area --%>
        <div class="shadow-retro-field bg-black h-[400px] relative overflow-hidden">
          <canvas id="game-surface" width="640" height="480" class="w-full h-full"></canvas>
          <p class="game-canvas__stub absolute inset-0 flex items-center justify-center text-xs text-gray-400">
            {dgettext("games", "Game engine initializing... Waiting for WebRTC connection.")}
          </p>
        </div>

        <%!-- Game media dock --%>
        <div
          id="game-media"
          phx-hook="GameMediaHook"
          class={[
            "game-media shadow-retro-field bg-surface",
            @game_call && "game-media--active",
            @game_call && @game_call[:type] == "video" && "game-media--video",
            @game_call && @game_call[:type] == "video" && "game-media--#{@game_call_layout}"
          ]}
          data-testid="game-media"
        >
          <audio id="game-remote-audio" autoplay></audio>

          <div :if={!@game_call} class="game-media__idle">
            <div class="game-media__status">
              <Icons.icon_status_signal class="w-3 h-3 shrink-0" />
              <span>{dgettext("games", "Media off")}</span>
            </div>
            <div class="game-media__actions">
              <.button
                size="sm"
                phx-click={@on_start_media}
                phx-value-type="audio"
                data-testid="game-media-start-audio"
              >
                <:icon><Icons.icon_microphone class="w-4 h-4" /></:icon>
                {dgettext("games", "Start Voice")}
              </.button>
              <.button
                size="sm"
                phx-click={@on_start_media}
                phx-value-type="video"
                data-testid="game-media-start-video"
              >
                <:icon><Icons.icon_camera class="w-4 h-4" /></:icon>
                {dgettext("games", "Start Video")}
              </.button>
            </div>
          </div>

          <div
            :if={@game_call}
            id="game-media-call"
            class={
              classes([
                "game-media__call",
                "p2p-media-call",
                "p2p-media-call--#{@game_call_layout}",
                @game_call[:type] == "video" && "p2p-media-call--video"
              ])
            }
            data-testid="game-media-call"
          >
            <div :if={@game_call[:type] == "video"} class="p2p-media-call__video-stage">
              <div class="p2p-media-call__remote-panel">
                <div class="p2p-media-call__nameplate">
                  <Icons.icon_camera class="w-3 h-3" />
                  <span>{@peer_nick}</span>
                </div>
                <video
                  id="game-remote-video"
                  class={[
                    "p2p-media-call__remote-video",
                    @game_call[:peer_camera_off] && "hidden"
                  ]}
                  autoplay
                  playsinline
                >
                </video>
                <div
                  :if={@game_call[:peer_camera_off]}
                  data-testid="game-media-peer-camera-off"
                  class="p2p-media-call__camera-off"
                >
                  <span>{dgettext("games", "Camera off")}</span>
                </div>
              </div>
              <div class="p2p-media-call__local-panel">
                <div class="p2p-media-call__nameplate">
                  <Icons.icon_camera class="w-3 h-3" />
                  <span>{dgettext("games", "%{nickname} (you)", nickname: @nickname)}</span>
                </div>
                <video
                  id="game-local-video"
                  class="p2p-media-call__local-video"
                  autoplay
                  playsinline
                  muted
                >
                </video>
              </div>
            </div>

            <div
              :if={@game_call[:peer_muted]}
              data-testid="game-media-peer-muted"
              class="game-media__peer-state"
            >
              <Icons.icon_mute class="w-3 h-3" />
              <span>{dgettext("games", "Peer muted")}</span>
            </div>

            <.toolbar class="game-media__toolbar" variant="compact">
              <.toolbar_button
                :if={!@game_call[:local_joined]}
                label={
                  if @game_call[:type] == "video",
                    do: dgettext("games", "Join Video"),
                    else: dgettext("games", "Join Voice")
                }
                variant="compact"
                phx-click={@on_start_media}
                phx-value-type={@game_call[:type]}
                data-testid="game-media-join"
              >
                <Icons.icon_camera :if={@game_call[:type] == "video"} class="w-4 h-4" />
                <Icons.icon_microphone :if={@game_call[:type] != "video"} class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_button
                :if={@game_call[:local_joined]}
                label={
                  if @local_muted,
                    do: dgettext("games", "Unmute"),
                    else: dgettext("games", "Mute")
                }
                active={@local_muted}
                variant="compact"
                data-game-media-action="mute"
                data-testid="game-media-mute"
              >
                <Icons.icon_mute :if={@local_muted} class="w-4 h-4" />
                <Icons.icon_microphone :if={!@local_muted} class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_button
                :if={@game_call[:local_joined] && @game_call[:type] == "video"}
                label={
                  if @local_camera_off,
                    do: dgettext("games", "Camera On"),
                    else: dgettext("games", "Camera Off")
                }
                active={@local_camera_off}
                variant="compact"
                data-game-media-action="camera"
                data-testid="game-media-camera"
              >
                <Icons.icon_camera_off :if={@local_camera_off} class="w-4 h-4" />
                <Icons.icon_camera :if={!@local_camera_off} class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_button
                :if={@game_call[:local_joined] && @game_call[:type] == "audio"}
                label={dgettext("games", "Add Video")}
                variant="compact"
                data-game-media-action="upgrade"
                data-testid="game-media-add-video"
              >
                <Icons.icon_upgrade_video class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_separator :if={@game_call[:type] == "video"} variant="compact" />
              <.toolbar_button
                :if={@game_call[:type] == "video"}
                label={dgettext("games", "Focus view")}
                active={@game_call_layout == "focus"}
                variant="compact"
                phx-click={@on_set_media_layout}
                phx-value-layout="focus"
                data-testid="game-media-layout-focus"
              >
                <Icons.icon_layout_focus class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_button
                :if={@game_call[:type] == "video"}
                label={dgettext("games", "Side-by-side view")}
                active={@game_call_layout == "side_by_side"}
                variant="compact"
                phx-click={@on_set_media_layout}
                phx-value-layout="side_by_side"
                data-testid="game-media-layout-side-by-side"
              >
                <Icons.icon_layout_side_by_side class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_button
                :if={@game_call[:type] == "video"}
                label={dgettext("games", "Maximize video")}
                active={@game_call_layout == "maximized"}
                variant="compact"
                phx-click={@on_set_media_layout}
                phx-value-layout="maximized"
                data-testid="game-media-layout-maximized"
              >
                <Icons.icon_layout_maximize class="w-4 h-4" />
              </.toolbar_button>
              <.toolbar_separator variant="compact" />
              <.toolbar_button
                label={dgettext("games", "End Call")}
                variant="compact"
                data-game-media-action="end-call"
                data-testid="game-media-end-call"
                class="text-error"
              >
                <Icons.icon_phone_end class="w-4 h-4" />
              </.toolbar_button>
              <span :if={@game_call[:duration]} class="game-media__duration">
                {@game_call[:duration]}
              </span>
            </.toolbar>
          </div>

          <div :if={@media_error} class="game-media__error">
            {@media_error}
          </div>
        </div>

        <%!-- Controls bar --%>
        <div class="flex items-center justify-between gap-retro-8">
          <%!-- Player labels --%>
          <div class="flex items-center gap-retro-8 text-xs">
            <div class="flex items-center gap-retro-2">
              <Icons.icon_status_user class="w-3 h-3 shrink-0" />
              <span class="font-bold">{@nickname}</span>
              <span :if={@role == :creator} class="text-muted-foreground">
                {dgettext("games", "(host)")}
              </span>
            </div>
            <span class="text-muted-foreground">{dgettext("games", "vs")}</span>
            <div class="flex items-center gap-retro-2">
              <Icons.icon_status_user class="w-3 h-3 shrink-0" />
              <span class="font-bold">{@peer_nick}</span>
              <span :if={@role != :creator} class="text-muted-foreground">
                {dgettext("games", "(host)")}
              </span>
            </div>
          </div>

          <%!-- End Game button --%>
          <.button
            variant="destructive"
            size="sm"
            phx-click={@on_end_game}
            data-testid="game-canvas-end"
          >
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {dgettext("games", "End Game")}
          </.button>
        </div>
      </.window_body>
    </.window>
    """
  end
end
