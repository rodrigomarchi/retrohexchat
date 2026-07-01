defmodule RetroHexChatWeb.Components.UI.Lobby.LobbyStatusBar do
  @moduledoc """
  Status bar for the lobby desktop's top bar.

  The lobby counterpart to `StatusBarApp`, composed from the same
  `window_status_bar`/`window_status_bar_field` primitives but surfacing
  lobby-relevant telemetry: the two participants (self and peer), the live
  WebRTC connection state, throughput and round-trip time derived from the
  host's `stats` map, and the clock.

  Bandwidth and latency read the same normalized `stats` the Statistics window
  uses, so no extra measurement (or `LagHook`) is needed — the clock is filled
  in client-side by `ClockHook`.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  attr :nickname, :string, required: true
  attr :peer_nick, :string, default: nil
  attr :peer_online, :boolean, default: false
  attr :connection_label, :string, default: nil
  attr :stats, :map, default: nil
  attr :class, :any, default: nil
  attr :rest, :global

  @spec lobby_status_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def lobby_status_bar(assigns) do
    conn = Map.get(assigns.stats || %{}, :connection, %{})

    assigns =
      assigns
      |> assign(:kbps, total_kbps(assigns.stats))
      |> assign(:rtt_ms, Map.get(conn, :rtt_ms, 0))

    ~H"""
    <.window_status_bar class={@class} data-testid="lobby-status-bar" {@rest}>
      <%!-- Participants --%>
      <.window_status_bar_field class="flex items-center gap-retro-2 min-w-0">
        <Icons.icon_status_user class="h-3 w-3 shrink-0" />
        <span class="truncate text-xs">{@nickname}</span>
        <span :if={@peer_nick} class="flex items-center gap-retro-2 min-w-0">
          <span class="text-muted-foreground text-xs">·</span>
          <span
            class={[
              "h-2 w-2 shrink-0 rounded-full",
              if(@peer_online, do: "bg-success", else: "bg-muted")
            ]}
            aria-hidden="true"
          >
          </span>
          <span class="truncate text-xs">{@peer_nick}</span>
        </span>
      </.window_status_bar_field>

      <%!-- Connection state --%>
      <.window_status_bar_field
        :if={@connection_label}
        grow
        class="hidden md:flex items-center gap-retro-2 min-w-0"
      >
        <Icons.icon_webrtc class="h-3 w-3 shrink-0" />
        <span class="truncate text-xs">{@connection_label}</span>
      </.window_status_bar_field>

      <%!-- Bandwidth + latency (from stats) --%>
      <.window_status_bar_field class="hidden md:flex items-center gap-retro-2 min-w-[112px]">
        <Icons.icon_status_signal class="h-3 w-3 shrink-0" />
        <span class="text-xs font-mono tabular-nums">{signal_text(@kbps, @rtt_ms)}</span>
      </.window_status_bar_field>

      <%!-- Clock --%>
      <.window_status_bar_field class="flex items-center gap-retro-2 min-w-[64px]">
        <Icons.icon_clock class="h-3 w-3 shrink-0" />
        <span id="lobby-status-clock" phx-hook="ClockHook" class="text-xs font-mono">--:--</span>
      </.window_status_bar_field>
    </.window_status_bar>
    """
  end

  # ── Private helpers ───────────────────────────────────

  # Total live WebRTC throughput across every active media/data channel, kbps.
  @spec total_kbps(map() | nil) :: non_neg_integer()
  defp total_kbps(nil), do: 0

  defp total_kbps(stats) do
    audio = Map.get(stats, :audio, %{})
    video = Map.get(stats, :video, %{})
    game = Map.get(stats, :game, %{})
    file = Map.get(stats, :file, %{})

    [
      Map.get(audio, :in_kbps, 0),
      Map.get(audio, :out_kbps, 0),
      Map.get(video, :in_kbps, 0),
      Map.get(video, :out_kbps, 0),
      Map.get(game, :sent_kbps, 0),
      Map.get(game, :recv_kbps, 0),
      Map.get(file, :sent_kbps, 0),
      Map.get(file, :recv_kbps, 0)
    ]
    |> Enum.sum()
    |> round()
  end

  @spec signal_text(non_neg_integer(), non_neg_integer()) :: String.t()
  defp signal_text(0, 0), do: "—"
  defp signal_text(kbps, 0), do: "#{kbps} kbps"
  defp signal_text(0, rtt), do: "#{rtt} ms"
  defp signal_text(kbps, rtt), do: "#{kbps} kbps · #{rtt} ms"
end
