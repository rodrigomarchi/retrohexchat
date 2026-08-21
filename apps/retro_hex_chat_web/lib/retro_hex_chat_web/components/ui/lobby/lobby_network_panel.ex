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
  import RetroHexChatWeb.Components.UI.MediaSession.DiagnosticsGroup
  import RetroHexChatWeb.Components.UI.MediaSession.StatusHeader
  import RetroHexChatWeb.Components.UI.MediaSession.SummaryCard
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
  attr :game_summary, :map, default: nil
  attr :recovery, :map, default: %{}
  attr :turn_only, :boolean, default: false

  @spec lobby_network_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def lobby_network_panel(assigns) do
    ~H"""
    <div
      id="p2p-stats-scroll-preserver"
      phx-hook="PreserveScrollHook"
      data-preserve-scroll-target="parent"
      class="flex flex-col gap-2"
      data-testid="lobby-network-panel"
    >
      <.session_header
        stats={@stats}
        peer_nick={@peer_nick}
        peer_online={@peer_online}
        session_status={@session_status}
        connection_label={@connection_label}
        call_summary={@call_summary}
        file_summary={@file_summary}
        game_summary={@game_summary}
        recovery={@recovery}
        turn_only={@turn_only}
      />

      <.tabs :let={builder} id="lobby-stats-tabs" default="network">
        <.tabs_list>
          <.stats_tab
            builder={builder}
            value="network"
            icon={:icon_protocol_p2p_compact}
            label={dgettext("p2p", "Network")}
            testid="p2p-stats-tab-network"
          />
          <.stats_tab
            builder={builder}
            value="audio"
            icon={:icon_microphone}
            label={dgettext("p2p", "Audio")}
            active={@stats.audio.active}
            testid="p2p-stats-tab-audio"
          />
          <.stats_tab
            builder={builder}
            value="video"
            icon={:icon_camera}
            label={dgettext("p2p", "Video")}
            active={@stats.video.active}
            testid="p2p-stats-tab-video"
          />
          <.stats_tab
            builder={builder}
            value="game"
            icon={:icon_joystick}
            label={dgettext("p2p", "Game")}
            active={@stats.game.active}
            testid="p2p-stats-tab-game"
          />
          <.stats_tab
            builder={builder}
            value="file"
            icon={:icon_file_send}
            label={dgettext("p2p", "File")}
            active={@stats.file.active}
            testid="p2p-stats-tab-file"
          />

          <%!-- Privacy + metric-help, tucked to the right of the tab strip so
                they don't cost a whole header row. --%>
          <div class="ml-auto flex items-center gap-2 self-center pl-2">
            <Icons.icon_privacy :if={@turn_only} class="text-muted-foreground h-3.5 w-3.5" />
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
          <.media_session_diagnostics_group
            title={dgettext("p2p", "Connection")}
            summary={p2p_connection_summary(@stats)}
            icon={:icon_status_signal}
            open
            testid="p2p-stats-details-connection"
          >
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
          </.media_session_diagnostics_group>

          <.media_session_diagnostics_group
            title={dgettext("p2p", "Recovery")}
            summary={p2p_recovery_summary(@recovery)}
            icon={:icon_warning}
            testid="p2p-stats-details-recovery"
          >
            <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px] text-xs">
              <.stat_row
                icon={:icon_status_signal}
                label={dgettext("p2p", "State")}
                value={p2p_recovery_state_label(@recovery)}
                tip={net_metric_tip(:recovery_state)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_warning}
                label={dgettext("p2p", "Reason")}
                value={technical_label(Map.get(@recovery || %{}, :reason))}
                tip={net_metric_tip(:recovery_reason)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_btn_connect_lightning}
                label={dgettext("p2p", "Trigger")}
                value={technical_label(Map.get(@recovery || %{}, :trigger))}
                tip={net_metric_tip(:recovery_trigger)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_btn_timers}
                label={dgettext("p2p", "Attempt")}
                value={p2p_attempt_label(@recovery)}
                tip={net_metric_tip(:recovery_attempt)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_webrtc}
                label={dgettext("p2p", "Signaling")}
                value={p2p_signaling_label(@stats)}
                tip={net_metric_tip(:signaling_epoch)}
                info_open={@info_open}
              />
              <.stat_row
                icon={:icon_protocol_p2p_compact}
                label={dgettext("p2p", "Offer")}
                value={technical_label(get_in(@stats, [:summary, :offer_id]))}
                tip={net_metric_tip(:offer_id)}
                info_open={@info_open}
              />
            </dl>
          </.media_session_diagnostics_group>
        </.tabs_content>

        <%!-- Audio --%>
        <.tabs_content value="audio" builder={builder}>
          <.media_session_diagnostics_group
            title={dgettext("p2p", "Audio")}
            summary={p2p_audio_summary(@stats.audio)}
            icon={:icon_microphone}
            testid="p2p-stats-details-audio"
          >
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
          </.media_session_diagnostics_group>
        </.tabs_content>

        <%!-- Video --%>
        <.tabs_content value="video" builder={builder}>
          <.media_session_diagnostics_group
            title={dgettext("p2p", "Video")}
            summary={p2p_video_detail(@stats.video)}
            icon={:icon_camera}
            testid="p2p-stats-details-video"
          >
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
                icon={:icon_screen_share}
                label={dgettext("p2p", "Source")}
                value={net_video_source_label(@stats.video.source)}
                tip={net_metric_tip(:source)}
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
          </.media_session_diagnostics_group>
        </.tabs_content>

        <%!-- Game data channel --%>
        <.tabs_content value="game" builder={builder}>
          <.media_session_diagnostics_group
            title={dgettext("p2p", "Games")}
            summary={p2p_channel_summary(@stats.game)}
            icon={:icon_joystick}
            testid="p2p-stats-details-game"
          >
            <.channel_metrics
              icon={:icon_joystick}
              channel={@stats.game}
              info_open={@info_open}
            />
          </.media_session_diagnostics_group>
        </.tabs_content>

        <%!-- File data channel --%>
        <.tabs_content value="file" builder={builder}>
          <.media_session_diagnostics_group
            title={dgettext("p2p", "Files")}
            summary={p2p_channel_summary(@stats.file)}
            icon={:icon_file_send}
            testid="p2p-stats-details-file"
          >
            <.channel_metrics
              icon={:icon_file_send}
              channel={@stats.file}
              info_open={@info_open}
            />
          </.media_session_diagnostics_group>
        </.tabs_content>
      </.tabs>
    </div>
    """
  end

  attr :stats, :map, required: true
  attr :peer_nick, :string, required: true
  attr :peer_online, :boolean, default: false
  attr :session_status, :string, required: true
  attr :connection_label, :string, default: nil
  attr :call_summary, :map, default: nil
  attr :file_summary, :map, default: nil
  attr :game_summary, :map, default: nil
  attr :recovery, :map, default: %{}
  attr :turn_only, :boolean, default: false

  defp session_header(assigns) do
    ~H"""
    <div
      class="grid gap-1 border border-border bg-surface p-2 shadow-retro-sunken"
      data-testid="p2p-stats-session-header"
    >
      <.media_session_status_header
        title={dgettext("p2p", "P2P session with %{peer}", peer: @peer_nick || "?")}
        class="bg-transparent p-0 shadow-none"
      >
        <:icon>
          <span class="flex h-8 w-8 shrink-0 items-center justify-center bg-canvas shadow-retro-sunken">
            <Icons.icon_protocol_p2p_compact class="h-5 w-5" />
          </span>
        </:icon>
        <:meta>
          <span class={["inline-flex items-center gap-1", session_status_class(@session_status)]}>
            <Icons.icon_status_signal class="h-3 w-3" />
            {session_status_label(@session_status)}
          </span>
          <span class="inline-flex items-center gap-1">
            <Icons.icon_webrtc class="h-3 w-3" />
            {@connection_label || dgettext("p2p", "Measuring")}
          </span>
          <span class="inline-flex items-center gap-1">
            <Icons.icon_status_user class="h-3 w-3" />
            {if @peer_online,
              do: dgettext("p2p", "Peer online"),
              else: dgettext("p2p", "Peer offline")}
          </span>
        </:meta>
        <:facets>
          <.session_badge :if={@call_summary} icon={:icon_camera} testid="p2p-stats-facet-call">
            {call_badge_label(@call_summary)}
          </.session_badge>
          <.session_badge :if={@file_summary} icon={:icon_file_send} testid="p2p-stats-facet-file">
            {dgettext("p2p", "File")}
          </.session_badge>
          <.session_badge
            :if={get_in(@game_summary || %{}, [:active?]) == true}
            icon={:icon_joystick}
            testid="p2p-stats-facet-game"
          >
            {dgettext("p2p", "Game")}
          </.session_badge>
          <.session_badge :if={@turn_only} icon={:icon_privacy} testid="p2p-stats-relay">
            {dgettext("p2p", "Relay")}
          </.session_badge>
        </:facets>
      </.media_session_status_header>

      <div
        class="grid grid-cols-2 gap-1 lg:grid-cols-4"
        aria-label={dgettext("p2p", "P2P health summary")}
        data-testid="p2p-stats-summary"
      >
        <.summary_card
          icon={:icon_quality_high}
          label={dgettext("p2p", "Health")}
          value={net_health_label(@stats.connection.level)}
          detail={dgettext("p2p", "MOS %{score}", score: format_mos(@stats.connection.mos))}
          tone_class={net_health_class(@stats.connection.level)}
          class="bg-canvas"
          testid="p2p-stats-summary-health"
        />
        <.summary_card
          icon={:icon_clock}
          label={dgettext("p2p", "Latency")}
          value={dgettext("p2p", "%{n} ms", n: @stats.connection.rtt_ms)}
          detail={
            dgettext("p2p", "%{jitter} ms jitter / %{loss}% loss",
              jitter: @stats.connection.jitter_ms,
              loss: @stats.connection.loss_pct
            )
          }
          class="bg-canvas"
          testid="p2p-stats-summary-latency"
        />
        <.summary_card
          icon={:icon_webrtc}
          label={dgettext("p2p", "Media")}
          value={p2p_media_summary(@stats)}
          detail={p2p_video_summary(@stats.video)}
          class="bg-canvas"
          testid="p2p-stats-summary-media"
        />
        <.summary_card
          icon={:icon_btn_connect_lightning}
          label={dgettext("p2p", "Data")}
          value={p2p_data_summary(@stats)}
          detail={p2p_data_detail(@stats)}
          class="bg-canvas"
          testid="p2p-stats-summary-data"
        />
      </div>
    </div>
    """
  end

  attr :icon, :atom, required: true
  attr :testid, :string, required: true
  slot :inner_block, required: true

  defp session_badge(assigns) do
    ~H"""
    <span
      class="inline-flex h-6 items-center gap-1 bg-canvas px-1.5 text-[10px] font-bold shadow-retro-sunken"
      data-testid={@testid}
    >
      {apply(Icons, @icon, [%{class: "h-3.5 w-3.5"}])}
      <span>{render_slot(@inner_block)}</span>
    </span>
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
  attr :testid, :string, default: nil

  defp stats_tab(assigns) do
    ~H"""
    <.tabs_trigger
      builder={@builder}
      value={@value}
      class="group px-retro-4"
      title={@label}
      aria-label={@label}
      data-testid={@testid}
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

  defp session_status_label("connected"), do: dgettext("p2p", "Connected")
  defp session_status_label("pending"), do: dgettext("p2p", "Pending")
  defp session_status_label("lobby"), do: dgettext("p2p", "Joining")
  defp session_status_label(_status), do: dgettext("p2p", "Session")

  defp session_status_class("connected"), do: "text-success"
  defp session_status_class("pending"), do: "text-warning"
  defp session_status_class(_status), do: "text-muted-foreground"

  defp call_badge_label(%{screen_sharing: true, duration: duration}) when is_binary(duration),
    do: dgettext("p2p", "Screen %{duration}", duration: duration)

  defp call_badge_label(%{duration: duration}) when is_binary(duration),
    do: dgettext("p2p", "Call %{duration}", duration: duration)

  defp call_badge_label(%{screen_sharing: true}), do: dgettext("p2p", "Screen")
  defp call_badge_label(%{type: "video"}), do: dgettext("p2p", "Video")
  defp call_badge_label(%{type: "audio"}), do: dgettext("p2p", "Audio")
  defp call_badge_label(_call), do: dgettext("p2p", "Call")

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

  defp net_video_source_label("screen"), do: dgettext("p2p", "Screen")
  defp net_video_source_label(_source), do: dgettext("p2p", "Camera")

  defp net_channel_state_label("open"), do: dgettext("p2p", "Open")
  defp net_channel_state_label("connecting"), do: dgettext("p2p", "Connecting")
  defp net_channel_state_label(_), do: dgettext("p2p", "Closed")

  defp p2p_media_summary(%{audio: %{active: true}, video: %{active: true}}),
    do: dgettext("p2p", "Audio + Video")

  defp p2p_media_summary(%{audio: %{active: true}}), do: dgettext("p2p", "Audio")
  defp p2p_media_summary(%{video: %{active: true}}), do: dgettext("p2p", "Video")
  defp p2p_media_summary(_stats), do: dgettext("p2p", "Idle")

  defp p2p_video_summary(%{active: true} = video), do: net_resolution_label(video)
  defp p2p_video_summary(_video), do: dgettext("p2p", "No video")

  defp p2p_data_summary(%{game: %{active: true}, file: %{active: true}}),
    do: dgettext("p2p", "Game + File")

  defp p2p_data_summary(%{game: %{active: true}}), do: dgettext("p2p", "Game")
  defp p2p_data_summary(%{file: %{active: true}}), do: dgettext("p2p", "File")
  defp p2p_data_summary(_stats), do: dgettext("p2p", "Idle")

  defp p2p_data_detail(%{game: %{active: true}, file: %{active: true}}),
    do: dgettext("p2p", "Both live")

  defp p2p_data_detail(%{game: %{active: true}}), do: dgettext("p2p", "Game live")
  defp p2p_data_detail(%{file: %{active: true}}), do: dgettext("p2p", "File live")
  defp p2p_data_detail(_stats), do: dgettext("p2p", "Game + files")

  defp p2p_connection_summary(stats) do
    dgettext("p2p", "%{latency} ms / %{loss}% loss",
      latency: stats.connection.rtt_ms,
      loss: stats.connection.loss_pct
    )
  end

  defp p2p_recovery_summary(recovery) do
    dgettext("p2p", "%{state} / %{reason}",
      state: p2p_recovery_state_label(recovery),
      reason: technical_label(Map.get(recovery || %{}, :reason))
    )
  end

  defp p2p_recovery_state_label(%{state: :idle}), do: dgettext("p2p", "Idle")
  defp p2p_recovery_state_label(%{state: :reconnecting}), do: dgettext("p2p", "Reconnecting")
  defp p2p_recovery_state_label(%{state: :failed}), do: dgettext("p2p", "Failed")
  defp p2p_recovery_state_label(%{state: state}) when is_atom(state), do: Atom.to_string(state)
  defp p2p_recovery_state_label(_recovery), do: dgettext("p2p", "Idle")

  defp p2p_attempt_label(%{attempt: attempt}) when is_integer(attempt) and attempt > 0,
    do: Integer.to_string(attempt)

  defp p2p_attempt_label(_recovery), do: dgettext("p2p", "None")

  defp p2p_signaling_label(%{summary: %{signaling_epoch: epoch}})
       when is_integer(epoch) and epoch > 0,
       do: dgettext("p2p", "Epoch %{epoch}", epoch: epoch)

  defp p2p_signaling_label(_stats), do: dgettext("p2p", "Not started")

  defp technical_label(value) when is_binary(value) and value != "", do: value
  defp technical_label(value) when is_atom(value) and not is_nil(value), do: Atom.to_string(value)
  defp technical_label(value) when is_integer(value), do: Integer.to_string(value)
  defp technical_label(_value), do: dgettext("p2p", "None")

  defp p2p_audio_summary(audio) do
    dgettext("p2p", "%{state} / %{down} down / %{up} up",
      state: if(audio.active, do: dgettext("p2p", "Active"), else: dgettext("p2p", "Idle")),
      down: dgettext("p2p", "%{n} kbps", n: audio.in_kbps),
      up: dgettext("p2p", "%{n} kbps", n: audio.out_kbps)
    )
  end

  defp p2p_video_detail(%{active: true} = video) do
    dgettext("p2p", "%{source} / %{resolution} / %{fps} fps",
      source: net_video_source_label(video.source),
      resolution: net_resolution_label(video),
      fps: video.fps
    )
  end

  defp p2p_video_detail(video) do
    dgettext("p2p", "%{state} / %{source}",
      state: dgettext("p2p", "Idle"),
      source: net_video_source_label(video.source)
    )
  end

  defp p2p_channel_summary(channel) do
    dgettext("p2p", "%{state} / %{sent} sent / %{received} received",
      state: net_channel_state_label(channel.state),
      sent: dgettext("p2p", "%{n} kbps", n: channel.sent_kbps),
      received: dgettext("p2p", "%{n} kbps", n: channel.recv_kbps)
    )
  end

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

  defp net_metric_tip(:recovery_state),
    do: dgettext("p2p", "Current recovery state reported by the call connection.")

  defp net_metric_tip(:recovery_reason),
    do: dgettext("p2p", "Low-cardinality reason for the latest recovery transition.")

  defp net_metric_tip(:recovery_trigger),
    do: dgettext("p2p", "Source that triggered recovery, such as browser, peer or server.")

  defp net_metric_tip(:recovery_attempt),
    do: dgettext("p2p", "Current automatic retry attempt for this recovery cycle.")

  defp net_metric_tip(:signaling_epoch),
    do: dgettext("p2p", "Current P2P signaling generation used to ignore stale SDP and ICE.")

  defp net_metric_tip(:offer_id),
    do: dgettext("p2p", "Current offer identifier used to ignore stale answers and candidates.")

  defp net_metric_tip(:download),
    do: dgettext("p2p", "Data currently being received from the peer, in kilobits per second.")

  defp net_metric_tip(:upload),
    do: dgettext("p2p", "Data currently being sent to the peer, in kilobits per second.")

  defp net_metric_tip(:video),
    do: dgettext("p2p", "Resolution of the received video, in pixels.")

  defp net_metric_tip(:source),
    do: dgettext("p2p", "Whether the active video RTP is camera or shared screen.")

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
