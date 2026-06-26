defmodule RetroHexChatWeb.Components.UI.Lobby.MediaPanel do
  @moduledoc """
  Self-controlled audio/video panel for the universal lobby — the body of the
  "Chamada" window.

  Hosts the `LobbyMediaHook` (mounted once the connection is up and kept mounted for
  the whole session) plus the call surface: video grid, mute/camera/PiP/devices
  controls, layout switch, quality presets and device selectors. Composed from the
  toolbar primitives and the icon facade.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Toolbar

  alias RetroHexChatWeb.Icons

  attr :connected, :boolean, default: false
  attr :call, :map, default: nil
  attr :call_layout, :string, required: true
  attr :peer_nick, :string, required: true
  attr :nickname, :string, required: true
  attr :local_muted, :boolean, required: true
  attr :local_camera_off, :boolean, required: true
  attr :peer_media, :map, required: true
  attr :devices, :map, default: nil

  @spec media_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def media_panel(assigns) do
    ~H"""
    <p :if={!@connected} class="text-muted-foreground flex items-center gap-2 p-2 text-xs">
      <Icons.icon_camera class="h-4 w-4 shrink-0" />
      {dgettext("lobby", "Connect to start an audio or video call.")}
    </p>

    <section
      :if={@connected}
      id="lobby-media"
      phx-hook="LobbyMediaHook"
      class="bg-accent p-2"
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
          "Start audio or video from the Lobby menu. The peer can do the same independently."
        )}
        <span :if={@peer_media.audio or @peer_media.video} class="font-bold">
          {dgettext("lobby", "%{peer} is sharing media.", peer: @peer_nick)}
        </span>
      </p>
    </section>
    """
  end
end
