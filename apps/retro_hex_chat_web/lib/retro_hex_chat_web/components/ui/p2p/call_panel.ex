defmodule RetroHexChatWeb.Components.UI.P2P.CallPanel do
  @moduledoc """
  Presentation component for the 1:1 P2P audio/video call window.

  The LiveComponent island owns state and events; this component owns the visual
  surface while preserving the DOM contract expected by `LobbyMediaHook`.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Toolbar

  alias RetroHexChatWeb.Icons

  attr :connected, :boolean, default: false
  attr :call, :map, default: nil
  attr :call_layout, :string, required: true
  attr :self_view, :string, default: "pip"
  attr :peer_nick, :string, required: true
  attr :nickname, :string, required: true
  attr :local_muted, :boolean, required: true
  attr :local_camera_off, :boolean, required: true
  attr :screen_sharing, :boolean, default: false
  attr :peer_media, :map, required: true
  attr :peer_camera_off, :boolean, default: false
  attr :peer_muted, :boolean, default: false
  attr :peer_screen_sharing, :boolean, default: false
  attr :reactions, :list, default: []
  attr :devices, :map, default: nil
  attr :mini, :boolean, default: false

  @spec call_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def call_panel(assigns) do
    assigns =
      assigns
      |> assign(:in_call, in_call?(assigns.call))
      |> assign(:peer_sharing, peer_sharing?(assigns.peer_media))
      |> assign(:normalized_layout, normalize_layout(assigns.call_layout))
      |> assign(:self_view_mode, normalize_self_view(Map.get(assigns, :self_view, "pip")))

    assigns = assign(assigns, :show_surface, assigns.in_call or assigns.peer_sharing)

    ~H"""
    <div
      class={["flex h-full min-h-0 flex-col gap-1 text-xs", @mini && "p2p-call-panel--mini"]}
      role="region"
      aria-label={dgettext("p2p", "P2P call")}
      data-testid="p2p-call-panel"
      data-call-mini={to_string(@mini)}
    >
      <div
        :if={!@connected}
        class="flex h-full min-h-[136px] flex-col items-center justify-center gap-2 border border-border bg-surface p-3 text-center shadow-retro-sunken"
        data-testid="p2p-call-disconnected"
      >
        <span class="flex h-10 w-10 items-center justify-center bg-canvas shadow-retro-sunken">
          <Icons.icon_p2p class="h-6 w-6" />
        </span>
        <div class="font-bold">{dgettext("p2p", "P2P media is offline")}</div>
        <p class="max-w-[28rem] text-muted-foreground">
          {dgettext("lobby", "Connect to start an audio or video call.")}
        </p>
      </div>

      <section
        :if={@connected}
        id="lobby-media"
        phx-hook="LobbyMediaHook"
        class="flex h-full min-h-0 flex-col gap-1 bg-accent p-1"
        data-testid="lobby-media-panel"
      >
        <.call_header
          call={@call}
          connected={@connected}
          peer_media={@peer_media}
          peer_nick={@peer_nick}
          peer_muted={@peer_muted}
          peer_camera_off={@peer_camera_off}
          peer_screen_sharing={@peer_screen_sharing}
        />

        <div
          :if={@show_surface}
          class={[
            "lobby-media min-h-0 flex-1",
            "lobby-media--#{@normalized_layout}",
            "lobby-media--self-#{@self_view_mode}",
            @mini && "lobby-media--mini"
          ]}
          data-testid="p2p-call-surface"
          data-call-layout={@normalized_layout}
          data-self-view={@self_view_mode}
          data-call-mini={to_string(@mini)}
        >
          <div
            class={video_grid_class(@normalized_layout, @self_view_mode, @mini)}
            data-testid="p2p-call-video-grid"
          >
            <div
              class={remote_tile_class(@normalized_layout, @self_view_mode)}
              role="button"
              tabindex="0"
              title={focus_title(@normalized_layout)}
              phx-click="set_call_layout"
              phx-value-layout={focus_toggle_layout(@normalized_layout)}
              data-testid="p2p-call-remote-tile"
              data-focused={to_string(@normalized_layout in ~w(focus speaker compact))}
              data-peer-screen-share={to_string(@peer_screen_sharing)}
            >
              <div
                :if={quality_label(@call)}
                class={[
                  "absolute left-2 top-2 z-10 flex items-center gap-1 bg-black/70 px-1.5 py-0.5 font-bold shadow-retro-sunken",
                  quality_class(quality_level(@call))
                ]}
                data-testid="lobby-call-quality"
              >
                <Icons.icon_status_signal class="h-3 w-3" />
                <span>{quality_label(@call)}</span>
              </div>

              <video
                id="lobby-remote-video"
                class={[
                  "block h-full min-h-[160px] w-full bg-black object-contain",
                  @peer_camera_off && "u-hidden"
                ]}
                autoplay
                playsinline
              >
              </video>

              <div
                :if={@peer_camera_off}
                data-testid="lobby-peer-camera-off"
                class="absolute inset-0 flex flex-col items-center justify-center gap-2 bg-canvas p-4 text-center shadow-retro-sunken"
              >
                <Icons.icon_camera_off class="h-7 w-7" />
                <div class="font-bold">
                  {dgettext("lobby", "%{peer}'s camera is off", peer: peer_label(@peer_nick))}
                </div>
                <p class="text-muted-foreground">
                  {dgettext("p2p", "Audio and data channels can keep running.")}
                </p>
              </div>

              <div class="absolute bottom-2 left-2 flex max-w-[70%] items-center gap-1 bg-black/70 px-1.5 py-0.5 font-bold text-white">
                <Icons.icon_screen_share
                  :if={@peer_screen_sharing}
                  class="h-3.5 w-3.5 shrink-0 text-warning"
                />
                <Icons.icon_p2p :if={!@peer_screen_sharing} class="h-3.5 w-3.5 shrink-0" />
                <span class="truncate">{peer_label(@peer_nick)}</span>
                <Icons.icon_mute :if={@peer_muted} class="h-3.5 w-3.5 shrink-0 text-warning" />
                <Icons.icon_camera_off
                  :if={@peer_camera_off}
                  class="h-3.5 w-3.5 shrink-0 text-warning"
                />
              </div>
              <.reaction_stack reactions={@reactions} source={:peer} testid="p2p-peer-reactions" />
            </div>

            <div
              :if={@in_call}
              class={local_tile_class(@self_view_mode)}
              data-testid="p2p-call-local-tile"
              data-self-view={@self_view_mode}
              data-screen-share={to_string(@screen_sharing)}
            >
              <video
                id="lobby-local-video"
                class="block h-full min-h-[72px] w-full bg-black object-cover"
                autoplay
                playsinline
                muted
                data-testid="p2p-local-self-view"
              >
              </video>
              <div class="absolute bottom-1 left-1 right-1 flex items-center gap-1 bg-black/70 px-1 py-0.5 font-bold text-white">
                <Icons.icon_screen_share
                  :if={@screen_sharing}
                  class="h-3.5 w-3.5 shrink-0 text-warning"
                />
                <Icons.icon_laptop :if={!@screen_sharing} class="h-3.5 w-3.5 shrink-0" />
                <span class="truncate">
                  {if @screen_sharing,
                    do: dgettext("p2p", "Your screen"),
                    else: dgettext("p2p", "You")}
                </span>
              </div>
              <.reaction_stack reactions={@reactions} source={:local} testid="p2p-local-reactions" />
            </div>

            <audio id="lobby-remote-audio" autoplay></audio>
          </div>

          <div
            :if={@peer_muted}
            data-testid="lobby-peer-muted"
            class="flex items-center gap-1 border border-border bg-surface px-2 py-1 font-bold shadow-retro-sunken"
          >
            <Icons.icon_mute class="h-3.5 w-3.5" />
            {dgettext("lobby", "%{peer} is muted", peer: peer_label(@peer_nick))}
          </div>

          <.sending_controls
            :if={@in_call}
            call={@call}
            call_layout={@call_layout}
            self_view={@self_view_mode}
            local_muted={@local_muted}
            local_camera_off={@local_camera_off}
            screen_sharing={@screen_sharing}
            peer_media={@peer_media}
            devices={@devices}
            mini={@mini}
          />
        </div>

        <.idle_call_state :if={!@show_surface} peer_nick={@peer_nick} />
      </section>
    </div>
    """
  end

  attr :call, :map, default: nil
  attr :connected, :boolean, required: true
  attr :peer_media, :map, required: true
  attr :peer_nick, :string, default: nil
  attr :peer_muted, :boolean, default: false
  attr :peer_camera_off, :boolean, default: false
  attr :peer_screen_sharing, :boolean, default: false

  defp call_header(assigns) do
    ~H"""
    <div
      class="flex min-h-8 shrink-0 flex-wrap items-center justify-between gap-1 border border-border bg-surface px-2 py-1 shadow-retro-sunken"
      data-testid="p2p-call-header"
    >
      <div class="flex min-w-0 items-center gap-2">
        <Icons.icon_p2p class="h-4 w-4 shrink-0" />
        <div class="min-w-0">
          <div class="truncate font-bold leading-4">
            {dgettext("p2p", "Direct call with %{peer}", peer: peer_label(@peer_nick))}
          </div>
          <div class="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-0.5 text-[10px] leading-3 text-muted-foreground">
            <span
              class="inline-flex min-w-0 items-center gap-1 truncate"
              aria-live="polite"
              data-testid="p2p-call-status-announcer"
            >
              <Icons.icon_status_signal class={[
                "h-3 w-3 shrink-0",
                status_icon_class(@connected, @call, @peer_media)
              ]} />
              <span class="truncate">{status_label(@connected, @call, @peer_media)}</span>
            </span>
            <span class="inline-flex items-center gap-1">
              <Icons.icon_status_user class="h-3 w-3 shrink-0" />
              {dgettext("p2p", "1:1")}
            </span>
            <span class="inline-flex items-center gap-1">
              <Icons.icon_webrtc class="h-3 w-3 shrink-0" />
              {track_label(@call, @peer_media)}
            </span>
          </div>
        </div>
      </div>

      <div class="flex max-w-full shrink-0 flex-wrap items-center justify-end gap-px">
        <span
          :if={duration_label(@call)}
          class="inline-flex h-6 items-center gap-1 bg-canvas px-1.5 font-bold shadow-retro-sunken"
          data-testid="p2p-call-duration"
        >
          <Icons.icon_clock class="h-3.5 w-3.5" />
          {duration_label(@call)}
        </span>
        <span class="inline-flex h-6 items-center gap-1 bg-canvas px-1.5 shadow-retro-sunken">
          <Icons.icon_microphone class={[
            "h-3.5 w-3.5",
            @peer_muted && "text-warning"
          ]} />
          <Icons.icon_camera class={[
            "h-3.5 w-3.5",
            @peer_camera_off && "text-warning"
          ]} />
          <Icons.icon_screen_share :if={@peer_screen_sharing} class="h-3.5 w-3.5 text-warning" />
        </span>
      </div>
    </div>
    """
  end

  attr :peer_nick, :string, default: nil

  defp idle_call_state(assigns) do
    ~H"""
    <div
      class="flex min-h-0 flex-1 flex-col justify-between gap-2 border border-border bg-surface p-2 shadow-retro-sunken"
      data-testid="p2p-call-idle"
    >
      <div class="flex min-h-[120px] flex-1 flex-col items-center justify-center gap-2 text-center">
        <span class="flex h-11 w-11 items-center justify-center bg-canvas shadow-retro-sunken">
          <Icons.icon_webrtc class="h-7 w-7" />
        </span>
        <div class="font-bold">{dgettext("p2p", "Ready for private media")}</div>
        <p class="max-w-[30rem] text-muted-foreground">
          {dgettext(
            "lobby",
            "Start audio or video — or the peer can, independently. You'll join automatically."
          )}
        </p>
      </div>

      <.toolbar
        class="flex-wrap items-center justify-center gap-1"
        aria-label={dgettext("p2p", "Start P2P media")}
      >
        <.toolbar_button
          label={dgettext("lobby", "Start audio")}
          variant="compact"
          phx-click="start_call"
          phx-value-type="audio"
          data-testid="lobby-call-start-audio"
        >
          <Icons.icon_microphone class="h-4 w-4" />
        </.toolbar_button>
        <.toolbar_button
          label={dgettext("lobby", "Start video")}
          variant="compact"
          phx-click="start_call"
          phx-value-type="video"
          data-testid="lobby-call-start-video"
        >
          <Icons.icon_camera class="h-4 w-4" />
        </.toolbar_button>
        <span class="ml-1 inline-flex items-center gap-1 text-muted-foreground">
          <Icons.icon_p2p class="h-3.5 w-3.5" />
          {peer_label(@peer_nick)}
        </span>
      </.toolbar>
    </div>
    """
  end

  attr :call, :map, required: true
  attr :call_layout, :string, required: true
  attr :self_view, :string, required: true
  attr :local_muted, :boolean, required: true
  attr :local_camera_off, :boolean, required: true
  attr :screen_sharing, :boolean, required: true
  attr :peer_media, :map, required: true
  attr :devices, :map, default: nil
  attr :mini, :boolean, default: false

  defp sending_controls(assigns) do
    ~H"""
    <div class="grid gap-1">
      <.toolbar
        class="flex-wrap items-center gap-1 border border-border px-1 py-1 shadow-retro-sunken"
        aria-label={dgettext("p2p", "P2P media controls")}
      >
        <.toolbar_button
          :if={!media_on?(@call, :audio)}
          label={dgettext("lobby", "Turn on microphone")}
          variant="compact"
          data-lobby-media-action="enable-audio"
          data-testid="p2p-call-enable-audio"
        >
          <Icons.icon_microphone class="h-4 w-4" />
        </.toolbar_button>
        <.toolbar_button
          :if={media_on?(@call, :audio)}
          label={if @local_muted, do: dgettext("lobby", "Unmute"), else: dgettext("lobby", "Mute")}
          active={@local_muted}
          variant="compact"
          data-lobby-media-action="mute"
          data-testid="p2p-call-toggle-mute"
        >
          <Icons.icon_mute :if={@local_muted} class="h-4 w-4" />
          <Icons.icon_microphone :if={!@local_muted} class="h-4 w-4" />
        </.toolbar_button>
        <.toolbar_button
          :if={!media_on?(@call, :video)}
          label={dgettext("lobby", "Turn on camera")}
          variant="compact"
          data-lobby-media-action="enable-video"
          data-testid="p2p-call-enable-video"
        >
          <Icons.icon_camera class="h-4 w-4" />
        </.toolbar_button>
        <.toolbar_button
          :if={media_on?(@call, :video)}
          label={
            if @local_camera_off,
              do: dgettext("lobby", "Camera On"),
              else: dgettext("lobby", "Camera Off")
          }
          active={@local_camera_off}
          variant="compact"
          data-lobby-media-action="camera"
          data-testid="p2p-call-toggle-camera"
        >
          <Icons.icon_camera_off :if={@local_camera_off} class="h-4 w-4" />
          <Icons.icon_camera :if={!@local_camera_off} class="h-4 w-4" />
        </.toolbar_button>
        <.toolbar_button
          :if={map_value(@peer_media, :video, false)}
          label={dgettext("lobby", "Picture-in-Picture")}
          variant="compact"
          data-lobby-media-action="pip"
          data-testid="p2p-call-pip"
        >
          <Icons.icon_pip class="h-4 w-4" />
        </.toolbar_button>
        <.toolbar_button
          label={
            if @screen_sharing,
              do: dgettext("p2p", "Stop sharing screen"),
              else: dgettext("p2p", "Share screen")
          }
          active={@screen_sharing}
          variant="compact"
          data-lobby-media-action="screen-share"
          data-testid="p2p-call-screen-share"
        >
          <Icons.icon_screen_share class="h-4 w-4" />
        </.toolbar_button>
        <.toolbar_separator :if={!@mini} variant="compact" />
        <.reaction_button
          :if={!@mini}
          reaction="heart"
          label={dgettext("p2p", "Send heart reaction")}
        />
        <.reaction_button
          :if={!@mini}
          reaction="thumbs_up"
          label={dgettext("p2p", "Send thumbs up")}
        />
        <.reaction_button :if={!@mini} reaction="clap" label={dgettext("p2p", "Send clap")} />
        <.reaction_button :if={!@mini} reaction="laugh" label={dgettext("p2p", "Send laugh")} />
        <.reaction_button :if={!@mini} reaction="sparkle" label={dgettext("p2p", "Send wow")} />
        <.toolbar_button
          :if={!@mini}
          label={dgettext("lobby", "Devices")}
          variant="compact"
          data-lobby-media-action="device-settings"
          data-testid="p2p-call-devices"
        >
          <Icons.icon_devices class="h-4 w-4" />
        </.toolbar_button>
        <.toolbar_separator variant="compact" />
        <.toolbar_button
          label={dgettext("p2p", "Dock statistics")}
          variant="compact"
          phx-click="p2p_dock_stats"
          data-testid="p2p-call-dock-stats"
        >
          <Icons.icon_status_signal class="h-4 w-4" />
        </.toolbar_button>
        <.toolbar_button
          label={
            if @mini,
              do: dgettext("p2p", "Expand call window"),
              else: dgettext("p2p", "Mini call window")
          }
          active={@mini}
          variant="compact"
          phx-click="p2p_toggle_call_mini"
          data-testid="p2p-call-mini-toggle"
        >
          <Icons.icon_win_restore :if={@mini} class="h-4 w-4" />
          <Icons.icon_win_minimize :if={!@mini} class="h-4 w-4" />
        </.toolbar_button>
        <.toolbar_button
          label={dgettext("lobby", "End call")}
          variant="compact"
          class="bg-destructive text-destructive-foreground"
          data-lobby-media-action="end-call"
          data-testid="p2p-call-end"
        >
          <Icons.icon_phone_end class="h-4 w-4" />
        </.toolbar_button>
        <span class="ml-auto inline-flex items-center gap-1 text-muted-foreground">
          <Icons.icon_webrtc class="h-3.5 w-3.5" />
          {call_type_label(@call, @screen_sharing)}
        </span>
      </.toolbar>

      <.layout_and_quality_controls
        :if={!@mini and (media_on?(@call, :video) or map_value(@peer_media, :video, false))}
        call_layout={@call_layout}
        self_view={@self_view}
      />

      <.device_selectors :if={!@mini} devices={@devices} />
    </div>
    """
  end

  attr :call_layout, :string, required: true
  attr :self_view, :string, required: true

  defp layout_and_quality_controls(assigns) do
    assigns = assign(assigns, :normalized_layout, normalize_layout(assigns.call_layout))

    ~H"""
    <.toolbar
      variant="compact"
      class="flex-wrap gap-1 border border-border px-1 py-1 shadow-retro-sunken"
      aria-label={dgettext("p2p", "P2P layout")}
      data-testid="p2p-call-layout-controls"
    >
      <.toolbar_button
        label={dgettext("p2p", "Auto layout")}
        active={@normalized_layout == "auto"}
        variant="compact"
        phx-click="set_call_layout"
        phx-value-layout="auto"
        data-testid="p2p-call-layout-auto"
      >
        <Icons.icon_layout_maximize class="h-4 w-4" />
      </.toolbar_button>
      <.toolbar_button
        label={dgettext("lobby", "Focus")}
        active={@normalized_layout == "focus"}
        variant="compact"
        phx-click="set_call_layout"
        phx-value-layout="focus"
        data-testid="p2p-call-layout-focus"
      >
        <Icons.icon_layout_focus class="h-4 w-4" />
      </.toolbar_button>
      <.toolbar_button
        label={dgettext("p2p", "Split")}
        active={@normalized_layout == "split"}
        variant="compact"
        phx-click="set_call_layout"
        phx-value-layout="split"
        data-testid="p2p-call-layout-split"
      >
        <Icons.icon_layout_side_by_side class="h-4 w-4" />
      </.toolbar_button>
      <.toolbar_button
        label={dgettext("p2p", "Speaker")}
        active={@normalized_layout == "speaker"}
        variant="compact"
        phx-click="set_call_layout"
        phx-value-layout="speaker"
        data-testid="p2p-call-layout-speaker"
      >
        <Icons.icon_microphone class="h-4 w-4" />
      </.toolbar_button>
      <.toolbar_button
        label={dgettext("p2p", "Compact")}
        active={@normalized_layout == "compact"}
        variant="compact"
        phx-click="set_call_layout"
        phx-value-layout="compact"
        data-testid="p2p-call-layout-compact"
      >
        <Icons.icon_win_minimize class="h-4 w-4" />
      </.toolbar_button>
      <.toolbar_button
        label={self_view_title(@self_view)}
        active={@self_view != "hidden"}
        variant="compact"
        phx-click="cycle_call_self_view"
        data-self-view={@self_view}
        data-testid="p2p-call-self-view-toggle"
      >
        <Icons.icon_pip class="h-4 w-4" />
      </.toolbar_button>
    </.toolbar>
    """
  end

  attr :reaction, :string, required: true
  attr :label, :string, required: true

  defp reaction_button(assigns) do
    ~H"""
    <.toolbar_button
      label={@label}
      variant="compact"
      phx-click="send_call_reaction"
      phx-value-reaction={@reaction}
      data-testid={"p2p-call-reaction-#{@reaction}"}
    >
      <.reaction_icon reaction={@reaction} class="h-4 w-4" />
    </.toolbar_button>
    """
  end

  attr :reactions, :list, default: []
  attr :source, :atom, required: true
  attr :testid, :string, required: true

  defp reaction_stack(assigns) do
    assigns =
      assign(
        assigns,
        :items,
        Enum.filter(assigns.reactions, &(Map.get(&1, :source) == assigns.source))
      )

    ~H"""
    <div
      :if={@items != []}
      class="pointer-events-none absolute left-1/2 top-4 z-30 flex -translate-x-1/2 gap-1"
      data-testid={@testid}
    >
      <span
        :for={item <- @items}
        class="inline-flex h-8 w-8 items-center justify-center border border-border bg-warning text-primary shadow-retro-raised"
        data-reaction={item.reaction}
      >
        <.reaction_icon reaction={item.reaction} class="h-5 w-5" />
      </span>
    </div>
    """
  end

  attr :reaction, :string, required: true
  attr :class, :string, default: nil

  defp reaction_icon(assigns) do
    ~H"""
    <Icons.icon_heart :if={@reaction == "heart"} class={@class} />
    <Icons.icon_thumbs_up :if={@reaction == "thumbs_up"} class={@class} />
    <Icons.icon_clap :if={@reaction == "clap"} class={@class} />
    <Icons.icon_laugh :if={@reaction == "laugh"} class={@class} />
    <Icons.icon_sparkle :if={@reaction == "sparkle"} class={@class} />
    """
  end

  attr :devices, :map, default: nil

  defp device_selectors(assigns) do
    ~H"""
    <div
      :if={@devices}
      class="grid gap-1 border border-border bg-surface p-1 shadow-retro-sunken sm:grid-cols-3"
      data-testid="lobby-devices"
    >
      <label
        :for={kind <- ~w(audioinput videoinput audiooutput)}
        :if={@devices[kind] not in [nil, []]}
        class="grid min-w-0 gap-0.5"
      >
        <span class="flex items-center gap-1 text-[10px] font-bold uppercase text-muted-foreground">
          <.device_icon kind={kind} />
          {device_label(kind)}
        </span>
        <select data-device-kind={kind} class="min-w-0 bg-input text-xs shadow-retro-sunken">
          <option :for={d <- @devices[kind]} value={d["id"]}>{d["label"]}</option>
        </select>
      </label>
    </div>
    """
  end

  attr :kind, :string, required: true

  defp device_icon(assigns) do
    ~H"""
    <Icons.icon_microphone :if={@kind == "audioinput"} class="h-3.5 w-3.5" />
    <Icons.icon_camera :if={@kind == "videoinput"} class="h-3.5 w-3.5" />
    <Icons.icon_devices :if={@kind == "audiooutput"} class="h-3.5 w-3.5" />
    """
  end

  @spec video_grid_class(String.t(), String.t(), boolean()) :: list()
  defp video_grid_class(_layout, _self_view, true) do
    [
      "relative grid min-h-[104px] gap-1 overflow-hidden border border-border bg-black p-1 shadow-retro-sunken"
    ]
  end

  defp video_grid_class("split", "tile", false) do
    [
      "relative grid min-h-[180px] gap-1 overflow-hidden border border-border bg-black p-1 shadow-retro-sunken",
      "sm:grid-cols-2"
    ]
  end

  defp video_grid_class("auto", "tile", false), do: video_grid_class("split", "tile", false)

  defp video_grid_class("compact", _self_view, false) do
    [
      "relative grid min-h-[128px] gap-1 overflow-hidden border border-border bg-black p-1 shadow-retro-sunken"
    ]
  end

  defp video_grid_class(_layout, _self_view, false) do
    [
      "relative grid min-h-[180px] gap-1 overflow-hidden border border-border bg-black p-1 shadow-retro-sunken"
    ]
  end

  @spec remote_tile_class(String.t(), String.t()) :: list()
  defp remote_tile_class("split", "tile"), do: base_tile_class()
  defp remote_tile_class("auto", "tile"), do: base_tile_class()

  defp remote_tile_class(_layout, _self_view) do
    base_tile_class() ++ ["min-h-[160px]"]
  end

  @spec local_tile_class(String.t()) :: list()
  defp local_tile_class("hidden"), do: ["hidden"]

  defp local_tile_class("tile") do
    base_tile_class() ++ ["min-h-[120px]"]
  end

  defp local_tile_class(_pip) do
    base_tile_class() ++
      [
        "absolute bottom-2 right-2 z-20 h-20 w-28 shadow-retro-raised"
      ]
  end

  defp base_tile_class do
    [
      "relative min-h-0 overflow-hidden border border-border bg-black text-white shadow-retro-sunken",
      "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
    ]
  end

  @spec normalize_layout(String.t()) :: String.t()
  defp normalize_layout("side_by_side"), do: "split"
  defp normalize_layout("maximized"), do: "compact"
  defp normalize_layout(layout) when layout in ~w(auto focus split speaker compact), do: layout
  defp normalize_layout(_layout), do: "focus"

  @spec normalize_self_view(String.t()) :: String.t()
  defp normalize_self_view(mode) when mode in ~w(tile pip hidden), do: mode
  defp normalize_self_view(_mode), do: "pip"

  @spec focus_toggle_layout(String.t()) :: String.t()
  defp focus_toggle_layout("focus"), do: "split"
  defp focus_toggle_layout(_layout), do: "focus"

  @spec focus_title(String.t()) :: String.t()
  defp focus_title("focus"), do: dgettext("p2p", "Return to split layout")
  defp focus_title(_layout), do: dgettext("p2p", "Focus peer video")

  @spec self_view_title(String.t()) :: String.t()
  defp self_view_title("tile"), do: dgettext("p2p", "Move self view to picture-in-picture")
  defp self_view_title("pip"), do: dgettext("p2p", "Hide self view")
  defp self_view_title("hidden"), do: dgettext("p2p", "Show self view as tile")
  defp self_view_title(_mode), do: dgettext("p2p", "Change self view")

  @spec in_call?(map() | nil) :: boolean()
  defp in_call?(call), do: is_map(call)

  @spec peer_sharing?(map()) :: boolean()
  defp peer_sharing?(peer_media) do
    map_value(peer_media, :audio, false) or map_value(peer_media, :video, false)
  end

  @spec media_on?(map() | nil, :audio | :video) :: boolean()
  defp media_on?(call, :audio), do: map_value(call, :audio_on, false)
  defp media_on?(call, :video), do: map_value(call, :video_on, false)

  @spec map_value(map() | nil, atom() | String.t(), any()) :: any()
  defp map_value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp map_value(_map, _key, default), do: default

  @spec peer_label(String.t() | nil) :: String.t()
  defp peer_label(peer_nick), do: peer_nick || dgettext("p2p", "peer")

  @spec status_label(boolean(), map() | nil, map()) :: String.t()
  defp status_label(false, _call, _peer_media), do: dgettext("p2p", "Disconnected")
  defp status_label(true, call, _peer_media) when is_map(call), do: active_status_label(call)

  defp status_label(true, _call, peer_media) do
    if peer_sharing?(peer_media), do: dgettext("p2p", "Receiving"), else: dgettext("p2p", "Ready")
  end

  defp active_status_label(call) do
    cond do
      map_value(call, :video_on, false) -> dgettext("p2p", "Video call active")
      map_value(call, :audio_on, false) -> dgettext("p2p", "Audio call active")
      true -> dgettext("p2p", "Receiving")
    end
  end

  @spec status_icon_class(boolean(), map() | nil, map()) :: String.t()
  defp status_icon_class(false, _call, _peer_media), do: "text-error"
  defp status_icon_class(true, call, _peer_media) when is_map(call), do: "text-success"

  defp status_icon_class(true, _call, peer_media) do
    if peer_sharing?(peer_media), do: "text-warning", else: "text-muted-foreground"
  end

  @spec track_label(map() | nil, map()) :: String.t()
  defp track_label(call, peer_media) do
    local =
      [:audio, :video]
      |> Enum.count(fn kind -> media_on?(call, kind) end)

    remote =
      [:audio, :video]
      |> Enum.count(fn kind -> map_value(peer_media, kind, false) end)

    dgettext("p2p", "%{count} tracks", count: local + remote)
  end

  @spec call_type_label(map(), boolean()) :: String.t()
  defp call_type_label(_call, true), do: dgettext("p2p", "Screen session")

  defp call_type_label(call, _screen_sharing) do
    case map_value(call, :type, "audio") do
      "video" -> dgettext("p2p", "Camera session")
      "receiving" -> dgettext("p2p", "Recv-only session")
      _other -> dgettext("p2p", "Audio session")
    end
  end

  @spec duration_label(map() | nil) :: String.t() | nil
  defp duration_label(call), do: map_value(call, :duration, nil)

  @spec quality_level(map() | nil) :: String.t() | nil
  defp quality_level(call), do: map_value(call, :quality_level, nil)

  @spec quality_label(map() | nil) :: String.t() | nil
  defp quality_label(call), do: map_value(call, :quality_label, nil)

  @spec quality_class(String.t() | nil) :: String.t()
  defp quality_class("excellent"), do: "text-success"
  defp quality_class("good"), do: "text-success"
  defp quality_class("fair"), do: "text-warning"
  defp quality_class("poor"), do: "text-error"
  defp quality_class(_level), do: "text-white"

  @spec device_label(String.t()) :: String.t()
  defp device_label("audioinput"), do: dgettext("p2p", "Mic")
  defp device_label("videoinput"), do: dgettext("p2p", "Camera")
  defp device_label("audiooutput"), do: dgettext("p2p", "Output")
end
