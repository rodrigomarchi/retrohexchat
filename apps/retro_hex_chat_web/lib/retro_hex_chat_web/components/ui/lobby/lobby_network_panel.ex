defmodule RetroHexChatWeb.Components.UI.Lobby.LobbyNetworkPanel do
  @moduledoc """
  Always-complete statistics panel for the universal lobby.

  Unlike a call-only telemetry strip, this panel renders EVERY section and metric
  at all times — Connection, Audio, Video, Games and Files — even when a feature
  is idle (it simply reads zero). The metrics are isolated per feature: audio and
  video come from their own RTP streams, games from the `gamedata` data channel and
  files from the `filetransfer` channel. Fed by `LobbyWebRTCHook`'s always-on
  poller (connection-to-close). Reuses the `p2p` gettext domain for metric labels.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Toolbar
  import RetroHexChatWeb.Components.UI.Fieldset

  alias RetroHexChatWeb.Icons

  attr :stats, :map, required: true
  attr :info_open, :boolean, default: false

  @spec lobby_network_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def lobby_network_panel(assigns) do
    ~H"""
    <div class="lobby__stats flex flex-col gap-2" data-testid="lobby-network-panel">
      <div class="flex items-center justify-end">
        <.toolbar variant="compact" class="gap-[1px]">
          <.toolbar_button
            label={dgettext("p2p", "What do these mean?")}
            active={@info_open}
            variant="compact"
            phx-click="toggle_network_info"
            data-testid="lobby-network-info"
          >
            <Icons.icon_question class="w-4 h-4" />
          </.toolbar_button>
        </.toolbar>
      </div>

      <.retro_fieldset legend={dgettext("p2p", "Connection")} class="lobby__stats-section">
        <div class="flex items-center gap-2 mb-1">
          <span
            class={["flex items-center gap-1", net_health_class(@stats.connection.level)]}
            title={net_metric_tip(:health)}
          >
            <Icons.icon_status_signal class="w-4 h-4" />
            <span class="text-xs font-bold" data-testid="lobby-network-health">
              {net_health_label(@stats.connection.level)}
            </span>
          </span>
          <span class="text-xs text-muted-foreground" title={net_metric_tip(:mos)}>
            {dgettext("p2p", "MOS %{score}", score: format_mos(@stats.connection.mos))}
          </span>
        </div>
        <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px] text-xs">
          <.stat_row
            label={dgettext("p2p", "Latency")}
            value={dgettext("p2p", "%{n} ms", n: @stats.connection.rtt_ms)}
            tip={net_metric_tip(:latency)}
            info_open={@info_open}
          />
          <.stat_row
            label={dgettext("p2p", "Jitter")}
            value={dgettext("p2p", "%{n} ms", n: @stats.connection.jitter_ms)}
            tip={net_metric_tip(:jitter)}
            info_open={@info_open}
          />
          <.stat_row
            label={dgettext("p2p", "Packet loss")}
            value={dgettext("p2p", "%{n}%", n: @stats.connection.loss_pct)}
            tip={net_metric_tip(:loss)}
            info_open={@info_open}
          />
          <.stat_row
            label={dgettext("p2p", "Capacity")}
            value={dgettext("p2p", "%{n} kbps", n: @stats.connection.available_kbps)}
            tip={net_metric_tip(:capacity)}
            info_open={@info_open}
          />
        </dl>
      </.retro_fieldset>

      <.retro_fieldset legend={dgettext("p2p", "Audio")} class="lobby__stats-section">
        <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px] text-xs">
          <.stat_status label={dgettext("p2p", "Status")} active={@stats.audio.active} />
          <.stat_row
            label={dgettext("p2p", "Download")}
            value={dgettext("p2p", "%{n} kbps", n: @stats.audio.in_kbps)}
            tip={net_metric_tip(:download)}
            info_open={@info_open}
          />
          <.stat_row
            label={dgettext("p2p", "Upload")}
            value={dgettext("p2p", "%{n} kbps", n: @stats.audio.out_kbps)}
            tip={net_metric_tip(:upload)}
            info_open={@info_open}
          />
          <.stat_row
            label={dgettext("p2p", "Packet loss")}
            value={dgettext("p2p", "%{n}%", n: @stats.audio.loss_pct)}
            tip={net_metric_tip(:loss)}
            info_open={@info_open}
          />
          <.stat_row
            label={dgettext("p2p", "Jitter")}
            value={dgettext("p2p", "%{n} ms", n: @stats.audio.jitter_ms)}
            tip={net_metric_tip(:jitter)}
            info_open={@info_open}
          />
        </dl>
      </.retro_fieldset>

      <.retro_fieldset legend={dgettext("p2p", "Video")} class="lobby__stats-section">
        <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px] text-xs">
          <.stat_status label={dgettext("p2p", "Status")} active={@stats.video.active} />
          <.stat_row
            label={dgettext("p2p", "Resolution")}
            value={net_resolution_label(@stats.video)}
            tip={net_metric_tip(:video)}
            info_open={@info_open}
          />
          <.stat_row
            label={dgettext("p2p", "Frame rate")}
            value={dgettext("p2p", "%{n} fps", n: @stats.video.fps)}
            tip={net_metric_tip(:fps)}
            info_open={@info_open}
          />
          <.stat_row
            label={dgettext("p2p", "Download")}
            value={dgettext("p2p", "%{n} kbps", n: @stats.video.in_kbps)}
            tip={net_metric_tip(:download)}
            info_open={@info_open}
          />
          <.stat_row
            label={dgettext("p2p", "Upload")}
            value={dgettext("p2p", "%{n} kbps", n: @stats.video.out_kbps)}
            tip={net_metric_tip(:upload)}
            info_open={@info_open}
          />
          <.stat_row
            label={dgettext("p2p", "Packet loss")}
            value={dgettext("p2p", "%{n}%", n: @stats.video.loss_pct)}
            tip={net_metric_tip(:loss)}
            info_open={@info_open}
          />
          <.stat_row
            label={dgettext("p2p", "Freezes")}
            value={Integer.to_string(@stats.video.freeze_count)}
            tip={net_metric_tip(:freezes)}
            info_open={@info_open}
          />
          <.stat_row
            label={dgettext("p2p", "Limited by")}
            value={net_limitation_label(@stats.video.limitation)}
            tip={net_metric_tip(:limitation)}
            info_open={@info_open}
          />
        </dl>
      </.retro_fieldset>

      <.retro_fieldset legend={dgettext("p2p", "Games")} class="lobby__stats-section">
        <.channel_metrics channel={@stats.game} info_open={@info_open} />
      </.retro_fieldset>

      <.retro_fieldset legend={dgettext("p2p", "Files")} class="lobby__stats-section">
        <.channel_metrics channel={@stats.file} info_open={@info_open} />
      </.retro_fieldset>
    </div>
    """
  end

  # Shared metric layout for a data-channel feature (games / files).
  attr :channel, :map, required: true
  attr :info_open, :boolean, default: false

  defp channel_metrics(assigns) do
    ~H"""
    <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px] text-xs">
      <.stat_status
        label={dgettext("p2p", "Status")}
        active={@channel.active}
        idle_label={net_channel_state_label(@channel.state)}
      />
      <.stat_row
        label={dgettext("p2p", "Sent")}
        value={dgettext("p2p", "%{n} kbps", n: @channel.sent_kbps)}
        tip={net_metric_tip(:upload)}
        info_open={@info_open}
      />
      <.stat_row
        label={dgettext("p2p", "Received")}
        value={dgettext("p2p", "%{n} kbps", n: @channel.recv_kbps)}
        tip={net_metric_tip(:download)}
        info_open={@info_open}
      />
      <.stat_row
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
  attr :tip, :string, default: nil
  attr :info_open, :boolean, default: false

  defp stat_row(assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class="flex justify-between gap-2" title={@tip}>
        <dt class="text-muted-foreground">{@label}</dt>
        <dd class="font-bold tabular-nums">{@value}</dd>
      </div>
      <p :if={@info_open && @tip} class="text-[10px] text-muted-foreground leading-tight">{@tip}</p>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :active, :boolean, required: true
  attr :idle_label, :string, default: nil

  defp stat_status(assigns) do
    ~H"""
    <div class="flex justify-between gap-2">
      <dt class="text-muted-foreground">{@label}</dt>
      <dd class={["font-bold", (@active && "text-success") || "text-muted-foreground"]}>
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
