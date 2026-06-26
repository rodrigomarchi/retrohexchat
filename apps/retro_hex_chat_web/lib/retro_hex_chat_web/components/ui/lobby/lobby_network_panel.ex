defmodule RetroHexChatWeb.Components.UI.Lobby.LobbyNetworkPanel do
  @moduledoc """
  Live WebRTC telemetry panel for the universal lobby.

  Renders connection health, MOS and the per-metric breakdown (latency, jitter,
  packet loss, throughput, video, limitation) with optional explanations. Copied
  from `RetroHexChatWeb.Components.UI.P2PLobby`'s private network panel so the
  lobby can show the same diagnostics alongside a call. Reuses the existing
  `p2p` gettext domain for the metric labels.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Toolbar
  import RetroHexChatWeb.Components.UI.Fieldset

  alias RetroHexChatWeb.Icons

  attr :stats, :map, required: true
  attr :collapsed, :boolean, default: false
  attr :info_open, :boolean, default: false

  @spec lobby_network_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def lobby_network_panel(assigns) do
    ~H"""
    <.retro_fieldset
      legend={dgettext("p2p", "Network")}
      class="lobby__net"
      data-testid="lobby-network-panel"
    >
      <div class="flex items-center gap-2 mb-1">
        <span
          class={["flex items-center gap-1", net_health_class(@stats[:level])]}
          title={net_metric_tip(:health)}
        >
          <Icons.icon_status_signal class="w-4 h-4" />
          <span class="text-xs font-bold" data-testid="lobby-network-health">
            {net_health_label(@stats[:level])}
          </span>
        </span>
        <span class="text-xs text-muted-foreground" title={net_metric_tip(:mos)}>
          {dgettext("p2p", "MOS %{score}", score: format_mos(@stats[:mos]))}
        </span>
        <.toolbar variant="compact" class="gap-[1px] ml-auto">
          <.toolbar_button
            label={dgettext("p2p", "What do these mean?")}
            active={@info_open}
            variant="compact"
            phx-click="toggle_network_info"
            data-testid="lobby-network-info"
          >
            <Icons.icon_question class="w-4 h-4" />
          </.toolbar_button>
          <.toolbar_button
            label={
              if @collapsed,
                do: dgettext("p2p", "Expand network panel"),
                else: dgettext("p2p", "Collapse network panel")
            }
            variant="compact"
            phx-click="toggle_network_panel"
            data-testid="lobby-network-toggle"
          >
            <Icons.icon_win_restore :if={@collapsed} class="w-4 h-4" />
            <Icons.icon_win_minimize :if={!@collapsed} class="w-4 h-4" />
          </.toolbar_button>
        </.toolbar>
      </div>
      <dl :if={!@collapsed} class="grid grid-cols-2 gap-x-3 gap-y-[2px] text-xs">
        <.net_row
          label={dgettext("p2p", "Latency")}
          value={dgettext("p2p", "%{n} ms", n: @stats[:rtt_ms])}
          tip={net_metric_tip(:latency)}
          info_open={@info_open}
        />
        <.net_row
          label={dgettext("p2p", "Jitter")}
          value={dgettext("p2p", "%{n} ms", n: @stats[:jitter_ms])}
          tip={net_metric_tip(:jitter)}
          info_open={@info_open}
        />
        <.net_row
          label={dgettext("p2p", "Packet loss")}
          value={dgettext("p2p", "%{n}%", n: @stats[:loss_pct])}
          tip={net_metric_tip(:loss)}
          info_open={@info_open}
        />
        <.net_row
          label={dgettext("p2p", "Download")}
          value={dgettext("p2p", "%{n} kbps", n: @stats[:inbound_kbps])}
          tip={net_metric_tip(:download)}
          info_open={@info_open}
        />
        <.net_row
          label={dgettext("p2p", "Upload")}
          value={dgettext("p2p", "%{n} kbps", n: @stats[:outbound_kbps])}
          tip={net_metric_tip(:upload)}
          info_open={@info_open}
        />
        <.net_row
          :if={@stats[:has_video]}
          label={dgettext("p2p", "Video")}
          value={net_video_label(@stats)}
          tip={net_metric_tip(:video)}
          info_open={@info_open}
        />
        <.net_row
          :if={@stats[:limitation] not in [nil, "none", ""]}
          label={dgettext("p2p", "Limited by")}
          value={net_limitation_label(@stats[:limitation])}
          tip={net_metric_tip(:limitation)}
          info_open={@info_open}
        />
      </dl>
    </.retro_fieldset>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :tip, :string, default: nil
  attr :info_open, :boolean, default: false

  defp net_row(assigns) do
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
  defp net_limitation_label(_), do: dgettext("p2p", "Other")

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

  defp net_metric_tip(:download),
    do: dgettext("p2p", "Media currently being received from the peer, in kilobits per second.")

  defp net_metric_tip(:upload),
    do: dgettext("p2p", "Media currently being sent to the peer, in kilobits per second.")

  defp net_metric_tip(:video),
    do: dgettext("p2p", "Resolution and frame rate of the received video.")

  defp net_metric_tip(:limitation),
    do:
      dgettext(
        "p2p",
        "Why quality was capped: CPU means your device is too busy; Bandwidth means the network is too slow."
      )

  @spec net_video_label(map()) :: String.t()
  defp net_video_label(stats) do
    dgettext("p2p", "%{w}×%{h} @ %{fps}fps",
      w: stats[:frame_width] || 0,
      h: stats[:frame_height] || 0,
      fps: stats[:fps] || 0
    )
  end

  @spec format_mos(number() | nil) :: String.t()
  defp format_mos(mos) when is_float(mos), do: :erlang.float_to_binary(mos, decimals: 1)
  defp format_mos(mos) when is_integer(mos), do: :erlang.float_to_binary(mos / 1, decimals: 1)
  defp format_mos(_), do: "—"
end
