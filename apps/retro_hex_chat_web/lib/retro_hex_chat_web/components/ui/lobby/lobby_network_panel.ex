defmodule RetroHexChatWeb.Components.UI.Lobby.LobbyNetworkPanel do
  @moduledoc """
  Tabbed statistics panel for the P2P session — the body of the "Statistics"
  window.

  A tab per view: **Network** (the full `p2p_connection_diagram` topology + whois
  plus the Connection-quality summary) and one per media/data channel — **Audio**,
  **Video**, **Game** and **File**. Every tab is always present; a channel tab
  lights up (colored label + pulse dot) while its channel is active, so the window
  shows what's live at a glance.

  Every metric renders at all times — even when a feature is idle it simply reads
  zero. The metrics are isolated per feature: audio and video come from their own
  RTP streams, games from the `gamedata` data channel and files from the
  `filetransfer` channel. Fed by `LobbyWebRTCHook`'s always-on poller. Reuses the
  `p2p` gettext domain for metric labels.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Toolbar
  import RetroHexChatWeb.Components.UI.Fieldset
  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.Components.UI.P2PConnectionDiagram

  alias RetroHexChatWeb.Icons

  attr :stats, :map, required: true
  attr :info_open, :boolean, default: false

  # Diagram / identity — drive the Network tab's topology + whois.
  attr :nickname, :string, required: true
  attr :peer_nick, :string, required: true
  attr :peer_online, :boolean, default: false
  attr :session_status, :string, required: true
  attr :connection_label, :string, default: nil
  attr :local_info, :map, default: %{}
  attr :peer_info, :map, default: %{}
  attr :call_summary, :map, default: nil
  attr :file_summary, :map, default: nil
  attr :turn_only, :boolean, default: false

  @spec lobby_network_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def lobby_network_panel(assigns) do
    ~H"""
    <div class="lobby__stats flex flex-col gap-2" data-testid="lobby-network-panel">
      <.tabs :let={builder} id="lobby-stats-tabs" default="network">
        <.tabs_list>
          <.stats_tab
            builder={builder}
            value="network"
            icon={:icon_p2p}
            label={dgettext("p2p", "Network")}
          />
          <.stats_tab
            builder={builder}
            value="audio"
            icon={:icon_microphone}
            label={dgettext("p2p", "Audio")}
            active={@stats.audio.active}
          />
          <.stats_tab
            builder={builder}
            value="video"
            icon={:icon_camera}
            label={dgettext("p2p", "Video")}
            active={@stats.video.active}
          />
          <.stats_tab
            builder={builder}
            value="game"
            icon={:icon_joystick}
            label={dgettext("p2p", "Game")}
            active={@stats.game.active}
          />
          <.stats_tab
            builder={builder}
            value="file"
            icon={:icon_file_send}
            label={dgettext("p2p", "File")}
            active={@stats.file.active}
          />

          <%!-- Privacy + metric-help, tucked to the right of the tab strip so
                they don't cost a whole header row. --%>
          <div class="ml-auto flex items-center gap-2 self-center pl-2">
            <Icons.icon_privacy
              :if={@turn_only}
              class="text-muted-foreground h-3.5 w-3.5"
              data-testid="lobby-tray-privacy"
            />
            <.toolbar variant="compact" class="gap-[1px]">
              <.toolbar_button
                label={dgettext("p2p", "What do these mean?")}
                active={@info_open}
                variant="compact"
                phx-click="toggle_network_info"
                data-testid="lobby-network-info"
              >
                <Icons.icon_question class="h-4 w-4" />
              </.toolbar_button>
            </.toolbar>
          </div>
        </.tabs_list>

        <%!-- Network: full diagram + connection quality --%>
        <.tabs_content value="network" builder={builder} class="flex flex-col gap-2">
          <.p2p_connection_diagram
            nickname={@nickname}
            peer_nick={@peer_nick}
            peer_online={@peer_online}
            session_status={@session_status}
            webrtc_state={@connection_label}
            file_transfer={@file_summary}
            call={@call_summary}
            local_info={@local_info}
            peer_info={@peer_info}
          />
          <.retro_fieldset legend={dgettext("p2p", "Connection")} class="lobby__stats-section">
            <div class="mb-1 flex items-center gap-2">
              <span
                class={["flex items-center gap-1", net_health_class(@stats.connection.level)]}
                title={net_metric_tip(:health)}
              >
                <Icons.icon_status_signal class="h-4 w-4" />
                <span class="text-xs font-bold" data-testid="lobby-network-health">
                  {net_health_label(@stats.connection.level)}
                </span>
              </span>
              <span
                class="text-muted-foreground flex items-center gap-1 text-xs"
                title={net_metric_tip(:mos)}
              >
                <Icons.icon_quality_high class="h-3.5 w-3.5" />
                {dgettext("p2p", "MOS %{score}", score: format_mos(@stats.connection.mos))}
              </span>
            </div>
            <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px] text-xs">
              <.stat_row
                icon={:icon_clock}
                label={dgettext("p2p", "Latency")}
                value={dgettext("p2p", "%{n} ms", n: @stats.connection.rtt_ms)}
                tip={net_metric_tip(:latency)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_btn_timers}
                label={dgettext("p2p", "Jitter")}
                value={dgettext("p2p", "%{n} ms", n: @stats.connection.jitter_ms)}
                tip={net_metric_tip(:jitter)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_warning}
                label={dgettext("p2p", "Packet loss")}
                value={dgettext("p2p", "%{n}%", n: @stats.connection.loss_pct)}
                tip={net_metric_tip(:loss)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_btn_connect_lightning}
                label={dgettext("p2p", "Capacity")}
                value={dgettext("p2p", "%{n} kbps", n: @stats.connection.available_kbps)}
                tip={net_metric_tip(:capacity)}
                info_open={@info_open}
              />
            </dl>
          </.retro_fieldset>
        </.tabs_content>

        <%!-- Audio --%>
        <.tabs_content value="audio" builder={builder}>
          <.retro_fieldset legend={dgettext("p2p", "Audio")} class="lobby__stats-section">
            <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px] text-xs">
              <.stat_status
                icon={:icon_microphone}
                label={dgettext("p2p", "Status")}
                active={@stats.audio.active}
              />
              <.stat_row
                icon={:icon_btn_down}
                label={dgettext("p2p", "Download")}
                value={dgettext("p2p", "%{n} kbps", n: @stats.audio.in_kbps)}
                tip={net_metric_tip(:download)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_btn_up}
                label={dgettext("p2p", "Upload")}
                value={dgettext("p2p", "%{n} kbps", n: @stats.audio.out_kbps)}
                tip={net_metric_tip(:upload)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_warning}
                label={dgettext("p2p", "Packet loss")}
                value={dgettext("p2p", "%{n}%", n: @stats.audio.loss_pct)}
                tip={net_metric_tip(:loss)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_btn_timers}
                label={dgettext("p2p", "Jitter")}
                value={dgettext("p2p", "%{n} ms", n: @stats.audio.jitter_ms)}
                tip={net_metric_tip(:jitter)}
                info_open={@info_open}
              />
            </dl>
          </.retro_fieldset>
        </.tabs_content>

        <%!-- Video --%>
        <.tabs_content value="video" builder={builder}>
          <.retro_fieldset legend={dgettext("p2p", "Video")} class="lobby__stats-section">
            <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px] text-xs">
              <.stat_status
                icon={:icon_camera}
                label={dgettext("p2p", "Status")}
                active={@stats.video.active}
              />
              <.stat_row
                icon={:icon_quality_high}
                label={dgettext("p2p", "Resolution")}
                value={net_resolution_label(@stats.video)}
                tip={net_metric_tip(:video)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_upgrade_video}
                label={dgettext("p2p", "Frame rate")}
                value={dgettext("p2p", "%{n} fps", n: @stats.video.fps)}
                tip={net_metric_tip(:fps)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_btn_down}
                label={dgettext("p2p", "Download")}
                value={dgettext("p2p", "%{n} kbps", n: @stats.video.in_kbps)}
                tip={net_metric_tip(:download)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_btn_up}
                label={dgettext("p2p", "Upload")}
                value={dgettext("p2p", "%{n} kbps", n: @stats.video.out_kbps)}
                tip={net_metric_tip(:upload)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_warning}
                label={dgettext("p2p", "Packet loss")}
                value={dgettext("p2p", "%{n}%", n: @stats.video.loss_pct)}
                tip={net_metric_tip(:loss)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_camera_off}
                label={dgettext("p2p", "Freezes")}
                value={Integer.to_string(@stats.video.freeze_count)}
                tip={net_metric_tip(:freezes)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_warning}
                label={dgettext("p2p", "Limited by")}
                value={net_limitation_label(@stats.video.limitation)}
                tip={net_metric_tip(:limitation)}
                info_open={@info_open}
              />
            </dl>
          </.retro_fieldset>
        </.tabs_content>

        <%!-- Game data channel --%>
        <.tabs_content value="game" builder={builder}>
          <.retro_fieldset legend={dgettext("p2p", "Games")} class="lobby__stats-section">
            <.channel_metrics
              icon={:icon_joystick}
              channel={@stats.game}
              info_open={@info_open}
            />
          </.retro_fieldset>
        </.tabs_content>

        <%!-- File data channel --%>
        <.tabs_content value="file" builder={builder}>
          <.retro_fieldset legend={dgettext("p2p", "Files")} class="lobby__stats-section">
            <.channel_metrics
              icon={:icon_file_send}
              channel={@stats.file}
              info_open={@info_open}
            />
          </.retro_fieldset>
        </.tabs_content>
      </.tabs>
    </div>
    """
  end

  # A statistics tab trigger. To fit every tab without scrolling, only the active
  # tab shows its text label (via CSS on `data-state`); the rest collapse to just
  # their icon, with the label in the tooltip. A green pulse dot marks a live
  # channel even while its tab is collapsed.
  attr :builder, :map, required: true
  attr :value, :string, required: true
  attr :icon, :atom, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  defp stats_tab(assigns) do
    ~H"""
    <.tabs_trigger
      builder={@builder}
      value={@value}
      class="group px-retro-4"
      title={@label}
      aria-label={@label}
    >
      <:icon>{apply(Icons, @icon, [%{class: "w-4 h-4"}])}</:icon>
      <span class={[
        "hidden group-data-[state=active]:inline",
        @active && "text-success font-bold"
      ]}>
        {@label}
      </span>
      <span
        :if={@active}
        class="bg-success ml-retro-2 h-1.5 w-1.5 shrink-0 animate-pulse rounded-full"
        aria-hidden="true"
      >
      </span>
    </.tabs_trigger>
    """
  end

  # Shared metric layout for a data-channel feature (games / files).
  attr :channel, :map, required: true
  attr :icon, :atom, required: true
  attr :info_open, :boolean, default: false

  defp channel_metrics(assigns) do
    ~H"""
    <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px] text-xs">
      <.stat_status
        icon={@icon}
        label={dgettext("p2p", "Status")}
        active={@channel.active}
        idle_label={net_channel_state_label(@channel.state)}
      />
      <.stat_row
        icon={:icon_btn_up}
        label={dgettext("p2p", "Sent")}
        value={dgettext("p2p", "%{n} kbps", n: @channel.sent_kbps)}
        tip={net_metric_tip(:upload)}
        info_open={@info_open}
      />
      <.stat_row
        icon={:icon_btn_down}
        label={dgettext("p2p", "Received")}
        value={dgettext("p2p", "%{n} kbps", n: @channel.recv_kbps)}
        tip={net_metric_tip(:download)}
        info_open={@info_open}
      />
      <.stat_row
        icon={:icon_btn_page}
        label={dgettext("p2p", "Messages")}
        value={Integer.to_string(@channel.messages)}
        tip={net_metric_tip(:messages)}
        info_open={@info_open}
      />
    </dl>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :icon, :atom, default: nil
  attr :tip, :string, default: nil
  attr :info_open, :boolean, default: false

  defp stat_row(assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class="flex items-center justify-between gap-2" title={@tip}>
        <dt class="text-muted-foreground flex min-w-0 items-center gap-1">
          <span :if={@icon} class="inline-flex shrink-0">
            {apply(Icons, @icon, [%{class: "w-3.5 h-3.5"}])}
          </span>
          <span class="truncate">{@label}</span>
        </dt>
        <dd class="shrink-0 font-bold tabular-nums">{@value}</dd>
      </div>
      <p :if={@info_open && @tip} class="text-muted-foreground text-[10px] leading-tight">{@tip}</p>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :active, :boolean, required: true
  attr :icon, :atom, default: nil
  attr :idle_label, :string, default: nil

  defp stat_status(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-2">
      <dt class="text-muted-foreground flex min-w-0 items-center gap-1">
        <span :if={@icon} class="inline-flex shrink-0">
          {apply(Icons, @icon, [%{class: "w-3.5 h-3.5"}])}
        </span>
        <span class="truncate">{@label}</span>
      </dt>
      <dd class={["shrink-0 font-bold", (@active && "text-success") || "text-muted-foreground"]}>
        {(@active && dgettext("p2p", "Active")) || @idle_label || dgettext("p2p", "Idle")}
      </dd>
    </div>
    """
  end

  defp net_health_class("excellent"), do: "text-success"
  defp net_health_class("good"), do: "text-success"
  defp net_health_class("fair"), do: "text-warning"
  defp net_health_class("poor"), do: "text-error"
  defp net_health_class(_), do: "text-muted-foreground"

  defp net_health_label("excellent"), do: dgettext("p2p", "Excellent")
  defp net_health_label("good"), do: dgettext("p2p", "Good")
  defp net_health_label("fair"), do: dgettext("p2p", "Fair")
  defp net_health_label("poor"), do: dgettext("p2p", "Poor")
  defp net_health_label(_), do: dgettext("p2p", "Measuring")

  defp net_limitation_label("cpu"), do: dgettext("p2p", "CPU")
  defp net_limitation_label("bandwidth"), do: dgettext("p2p", "Bandwidth")
  defp net_limitation_label(limit) when limit in [nil, "none", ""], do: dgettext("p2p", "Nothing")
  defp net_limitation_label(_), do: dgettext("p2p", "Other")

  defp net_channel_state_label("open"), do: dgettext("p2p", "Open")
  defp net_channel_state_label("connecting"), do: dgettext("p2p", "Connecting")
  defp net_channel_state_label(_), do: dgettext("p2p", "Closed")

  @spec net_metric_tip(atom()) :: String.t()
  defp net_metric_tip(:health),
    do:
      dgettext(
        "p2p",
        "Overall connection health, rated from Excellent to Poor based on the MOS score."
      )

  defp net_metric_tip(:mos),
    do:
      dgettext(
        "p2p",
        "Mean Opinion Score (1-5): an overall call-quality estimate from latency, jitter and loss. 5 is excellent; below 3.5 feels poor."
      )

  defp net_metric_tip(:latency),
    do:
      dgettext(
        "p2p",
        "Round-trip time for data to reach the peer and return. Lower is better; under ~150 ms feels instant."
      )

  defp net_metric_tip(:jitter),
    do:
      dgettext(
        "p2p",
        "Variation in packet arrival timing. High jitter causes choppy audio and video."
      )

  defp net_metric_tip(:loss),
    do:
      dgettext(
        "p2p",
        "Percentage of packets that never arrived. Above ~3% noticeably degrades quality."
      )

  defp net_metric_tip(:capacity),
    do:
      dgettext(
        "p2p",
        "Estimated bandwidth available for sending to the peer, in kilobits per second."
      )

  defp net_metric_tip(:download),
    do: dgettext("p2p", "Data currently being received from the peer, in kilobits per second.")

  defp net_metric_tip(:upload),
    do: dgettext("p2p", "Data currently being sent to the peer, in kilobits per second.")

  defp net_metric_tip(:video),
    do: dgettext("p2p", "Resolution of the received video, in pixels.")

  defp net_metric_tip(:fps),
    do: dgettext("p2p", "Frames per second of the received video. Higher is smoother.")

  defp net_metric_tip(:freezes),
    do: dgettext("p2p", "How many times the received video stalled momentarily.")

  defp net_metric_tip(:messages),
    do: dgettext("p2p", "Total messages exchanged over this feature's data channel.")

  defp net_metric_tip(:limitation),
    do:
      dgettext(
        "p2p",
        "Why quality was capped: CPU means your device is too busy; Bandwidth means the network is too slow."
      )

  @spec net_resolution_label(map()) :: String.t()
  defp net_resolution_label(%{width: w, height: h}) when w > 0 and h > 0 do
    dgettext("p2p", "%{w}×%{h}", w: w, h: h)
  end

  defp net_resolution_label(_), do: "—"

  @spec format_mos(number() | nil) :: String.t()
  defp format_mos(mos) when is_float(mos), do: :erlang.float_to_binary(mos, decimals: 1)
  defp format_mos(mos) when is_integer(mos), do: :erlang.float_to_binary(mos / 1, decimals: 1)
  defp format_mos(_), do: "—"
end
