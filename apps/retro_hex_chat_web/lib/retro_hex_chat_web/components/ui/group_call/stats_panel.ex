defmodule RetroHexChatWeb.Components.UI.GroupCall.StatsPanel do
  @moduledoc """
  Live network statistics panel for a channel conference.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Fieldset

  alias RetroHexChatWeb.Icons

  attr :call, :map, required: true
  attr :stats, :map, required: true

  @spec group_call_stats_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def group_call_stats_panel(assigns) do
    ~H"""
    <div
      id="group-call-stats-scroll-preserver"
      phx-hook="PreserveScrollHook"
      data-preserve-scroll-target="parent"
      class="flex min-h-0 flex-col gap-2 text-xs"
      data-testid="group-call-stats-panel"
    >
      <div class="shadow-retro-field bg-canvas p-2">
        <div class="flex items-center justify-between gap-2">
          <div class="flex min-w-0 items-center gap-2">
            <Icons.icon_conference class="h-5 w-5 shrink-0" />
            <div class="min-w-0">
              <div class="truncate font-bold">{@call.channel_name}</div>
              <div class="flex min-w-0 items-center gap-2 text-muted-foreground">
                <span class="inline-flex min-w-0 items-center gap-1 truncate">
                  <Icons.icon_laptop class="h-3 w-3 shrink-0" />
                  <span class="truncate">
                    {dgettext("group_call", "Browser %{state}",
                      state: connection_state(@call, @stats)
                    )}
                  </span>
                </span>
                <span class="inline-flex shrink-0 items-center gap-1">
                  <Icons.icon_server class="h-3 w-3 shrink-0" />
                  {room_status(@call)}
                </span>
              </div>
            </div>
          </div>
          <div class="flex shrink-0 items-center gap-1">
            <Icons.icon_community class="h-3.5 w-3.5" />
            <span data-testid="group-call-stats-participants">
              {participant_count(@call, @stats)}
            </span>
          </div>
        </div>
      </div>

      <.retro_fieldset legend={dgettext("group_call", "Server")}>
        <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px]">
          <.stat_row
            icon={:icon_server}
            label={dgettext("group_call", "Room")}
            value={room_status(@call)}
          />
          <.stat_row
            icon={:icon_community}
            label={dgettext("group_call", "Participants")}
            value={server_participant_summary(@call)}
          />
          <.stat_row
            icon={:icon_microphone}
            label={dgettext("group_call", "Audio tracks")}
            value={track_summary(@call, "audio")}
          />
          <.stat_row
            icon={:icon_camera}
            label={dgettext("group_call", "Video tracks")}
            value={track_summary(@call, "video")}
          />
          <.stat_row
            icon={:icon_screen_share}
            label={dgettext("group_call", "Screen tracks")}
            value={screen_track_summary(@call)}
          />
          <.stat_row
            icon={:icon_btn_timers}
            label={dgettext("group_call", "Pending")}
            value={Integer.to_string(pending_participant_count(@call))}
          />
          <.stat_row
            icon={:icon_webrtc}
            label={dgettext("group_call", "Track total")}
            value={Integer.to_string(track_count(@call, @stats))}
          />
        </dl>
      </.retro_fieldset>

      <.retro_fieldset legend={dgettext("group_call", "Server runtime")}>
        <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px]">
          <.stat_row
            icon={:icon_server}
            label={dgettext("group_call", "Peer connections")}
            value={server_peer_summary(@call)}
          />
          <.stat_row
            icon={:icon_webrtc}
            label={dgettext("group_call", "Server tracks")}
            value={server_track_summary(@call)}
          />
          <.stat_row
            icon={:icon_btn_connect_lightning}
            label={dgettext("group_call", "Fanout")}
            value={server_fanout_summary(@call)}
          />
          <.stat_row
            icon={:icon_btn_down}
            label={dgettext("group_call", "Inbound RTP")}
            value={server_rtp_summary(@call, :inbound)}
          />
          <.stat_row
            icon={:icon_btn_up}
            label={dgettext("group_call", "Outbound RTP")}
            value={server_rtp_summary(@call, :outbound)}
          />
          <.stat_row
            icon={:icon_globe}
            label={dgettext("group_call", "ICE pairs")}
            value={server_ice_pair_summary(@call)}
          />
          <.stat_row
            icon={:icon_webrtc}
            label={dgettext("group_call", "ICE traffic")}
            value={server_ice_traffic_summary(@call)}
          />
          <.stat_row
            icon={:icon_warning}
            label={dgettext("group_call", "RTCP feedback")}
            value={server_feedback_summary(@call)}
          />
        </dl>
      </.retro_fieldset>

      <.retro_fieldset :if={server_peers(@call) != []} legend={dgettext("group_call", "Server peers")}>
        <div class="grid gap-1">
          <.server_peer_card :for={peer <- server_peers(@call)} peer={peer} />
        </div>
      </.retro_fieldset>

      <.retro_fieldset legend={dgettext("group_call", "Browser connection")}>
        <div class="mb-1 flex items-center justify-between gap-2">
          <span
            class={["flex items-center gap-1 font-bold", health_class(@stats.connection.level)]}
            data-testid="group-call-stats-health"
          >
            <Icons.icon_laptop class="h-4 w-4" />
            {health_label(@stats.connection.level)}
          </span>
          <span class="text-muted-foreground flex items-center gap-1">
            <Icons.icon_quality_high class="h-3.5 w-3.5" />
            {dgettext("group_call", "MOS %{score}", score: format_mos(@stats.connection.mos))}
          </span>
        </div>
        <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px]">
          <.stat_row
            icon={:icon_clock}
            label={dgettext("group_call", "Latency")}
            value={dgettext("group_call", "%{n} ms", n: @stats.connection.rtt_ms)}
          />
          <.stat_row
            icon={:icon_btn_timers}
            label={dgettext("group_call", "Jitter")}
            value={dgettext("group_call", "%{n} ms", n: @stats.connection.jitter_ms)}
          />
          <.stat_row
            icon={:icon_warning}
            label={dgettext("group_call", "Packet loss")}
            value={dgettext("group_call", "%{n}%", n: @stats.connection.loss_pct)}
          />
          <.stat_row
            icon={:icon_btn_connect_lightning}
            label={dgettext("group_call", "Capacity")}
            value={dgettext("group_call", "%{n} kbps", n: @stats.connection.available_kbps)}
          />
        </dl>
      </.retro_fieldset>

      <.retro_fieldset legend={dgettext("group_call", "Audio")}>
        <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px]">
          <.stat_status
            icon={:icon_microphone}
            label={dgettext("group_call", "Status")}
            active={@stats.audio.active}
          />
          <.stat_row
            icon={:icon_btn_down}
            label={dgettext("group_call", "Download")}
            value={dgettext("group_call", "%{n} kbps", n: @stats.audio.in_kbps)}
          />
          <.stat_row
            icon={:icon_btn_up}
            label={dgettext("group_call", "Upload")}
            value={dgettext("group_call", "%{n} kbps", n: @stats.audio.out_kbps)}
          />
          <.stat_row
            icon={:icon_warning}
            label={dgettext("group_call", "Packet loss")}
            value={dgettext("group_call", "%{n}%", n: @stats.audio.loss_pct)}
          />
        </dl>
      </.retro_fieldset>

      <.retro_fieldset legend={dgettext("group_call", "Video")}>
        <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px]">
          <.stat_status
            icon={:icon_camera}
            label={dgettext("group_call", "Status")}
            active={@stats.video.active}
          />
          <.stat_row
            icon={:icon_quality_high}
            label={dgettext("group_call", "Resolution")}
            value={resolution_label(@stats.video)}
          />
          <.stat_row
            icon={:icon_upgrade_video}
            label={dgettext("group_call", "Frame rate")}
            value={dgettext("group_call", "%{n} fps", n: @stats.video.fps)}
          />
          <.stat_row
            icon={:icon_btn_down}
            label={dgettext("group_call", "Download")}
            value={dgettext("group_call", "%{n} kbps", n: @stats.video.in_kbps)}
          />
          <.stat_row
            icon={:icon_btn_up}
            label={dgettext("group_call", "Upload")}
            value={dgettext("group_call", "%{n} kbps", n: @stats.video.out_kbps)}
          />
          <.stat_row
            icon={:icon_warning}
            label={dgettext("group_call", "Packet loss")}
            value={dgettext("group_call", "%{n}%", n: @stats.video.loss_pct)}
          />
          <.stat_row
            icon={:icon_camera_off}
            label={dgettext("group_call", "Freezes")}
            value={Integer.to_string(@stats.video.freeze_count)}
          />
          <.stat_row
            icon={:icon_warning}
            label={dgettext("group_call", "Limited by")}
            value={limitation_label(@stats.video.limitation)}
          />
        </dl>
      </.retro_fieldset>

      <.retro_fieldset legend={dgettext("group_call", "Browser summary")}>
        <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px]">
          <.stat_row
            icon={:icon_community}
            label={dgettext("group_call", "Participants")}
            value={Integer.to_string(participant_count(@call, @stats))}
          />
          <.stat_row
            icon={:icon_camera}
            label={dgettext("group_call", "Remote streams")}
            value={Integer.to_string(@stats.summary.remote_stream_count)}
          />
          <.stat_row
            icon={:icon_quality_high}
            label={dgettext("group_call", "Tracks")}
            value={Integer.to_string(track_count(@call, @stats))}
          />
          <.stat_row
            icon={:icon_status_signal}
            label={dgettext("group_call", "ICE")}
            value={connection_state(@call, @stats)}
          />
        </dl>
      </.retro_fieldset>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :icon, :atom, required: true

  defp stat_row(assigns) do
    ~H"""
    <div class="contents">
      <dt class="text-muted-foreground flex min-w-0 items-center gap-1 truncate">
        {apply(Icons, @icon, [%{class: "h-3.5 w-3.5 shrink-0"}])}
        <span class="truncate">{@label}</span>
      </dt>
      <dd class="truncate text-right font-mono">{@value}</dd>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :active, :boolean, required: true
  attr :icon, :atom, required: true

  defp stat_status(assigns) do
    assigns =
      assign(assigns,
        label_text:
          if(assigns.active,
            do: dgettext("group_call", "Active"),
            else: dgettext("group_call", "Idle")
          )
      )

    ~H"""
    <div class="contents">
      <dt class="text-muted-foreground flex min-w-0 items-center gap-1 truncate">
        {apply(Icons, @icon, [%{class: "h-3.5 w-3.5 shrink-0"}])}
        <span class="truncate">{@label}</span>
      </dt>
      <dd class={[
        "truncate text-right font-bold",
        @active && "text-success",
        !@active && "text-muted-foreground"
      ]}>
        {@label_text}
      </dd>
    </div>
    """
  end

  attr :peer, :map, required: true

  defp server_peer_card(assigns) do
    ~H"""
    <article
      class="grid gap-1 border border-border bg-surface px-1.5 py-1 shadow-retro-sunken"
      data-testid={"group-call-stats-server-peer-#{peer_dom_id(@peer)}"}
    >
      <div class="flex min-w-0 items-center justify-between gap-2">
        <span class="inline-flex min-w-0 items-center gap-1 font-bold">
          <Icons.icon_status_user class="h-3.5 w-3.5 shrink-0" />
          <span class="truncate">{peer_label(@peer)}</span>
        </span>
        <span class="inline-flex shrink-0 items-center gap-1 text-[10px] text-muted-foreground">
          <Icons.icon_status_signal class="h-3 w-3" />
          {peer_state_summary(@peer)}
        </span>
      </div>

      <dl class="grid grid-cols-2 gap-x-3 gap-y-[2px]">
        <.stat_row
          icon={:icon_webrtc}
          label={dgettext("group_call", "Tracks")}
          value={peer_track_summary(@peer)}
        />
        <.stat_row
          icon={:icon_btn_connect_lightning}
          label={dgettext("group_call", "Subscribers")}
          value={dgettext("group_call", "%{n} subs", n: field(@peer, :subscriber_count, 0))}
        />
        <.stat_row
          icon={:icon_btn_down}
          label={dgettext("group_call", "Inbound RTP")}
          value={peer_rtp_summary(@peer, :inbound_rtp)}
        />
        <.stat_row
          icon={:icon_btn_up}
          label={dgettext("group_call", "Outbound RTP")}
          value={peer_rtp_summary(@peer, :outbound_rtp)}
        />
        <.stat_row
          icon={:icon_globe}
          label={dgettext("group_call", "ICE pairs")}
          value={peer_ice_pair_summary(@peer)}
        />
        <.stat_row
          icon={:icon_webrtc}
          label={dgettext("group_call", "ICE traffic")}
          value={peer_ice_traffic_summary(@peer)}
        />
        <.stat_row
          icon={:icon_warning}
          label={dgettext("group_call", "RTCP feedback")}
          value={peer_feedback_summary(@peer)}
        />
        <.stat_row
          icon={:icon_status_signal}
          label={dgettext("group_call", "Signaling")}
          value={to_string(field(@peer, :signaling_state, "unknown"))}
        />
      </dl>
    </article>
    """
  end

  defp participant_count(_call, %{summary: %{participant_count: count}}) when count > 0,
    do: count

  defp participant_count(%{participants: participants}, _stats) when is_list(participants),
    do: length(participants)

  defp participant_count(_call, _stats), do: 0

  defp track_count(_call, %{summary: %{track_count: count}}) when count > 0, do: count
  defp track_count(%{tracks: tracks}, _stats) when is_list(tracks), do: length(tracks)
  defp track_count(_call, _stats), do: 0

  defp room_status(%{room: %{status: status, max_participants: max}}) do
    dgettext("group_call", "%{status} / max %{max}", status: status || "?", max: max || 0)
  end

  defp room_status(_call), do: dgettext("group_call", "Unknown")

  defp server_totals(%{server_stats: %{totals: totals}}) when is_map(totals), do: totals
  defp server_totals(_call), do: %{}

  defp server_room(%{server_stats: %{room: room}}) when is_map(room), do: room
  defp server_room(_call), do: %{}

  defp server_peers(%{server_stats: %{peers: peers}}) when is_list(peers), do: peers
  defp server_peers(_call), do: []

  defp server_peer_summary(call) do
    totals = server_totals(call)

    dgettext("group_call", "%{connected}/%{total} connected",
      connected: Map.get(totals, :connected_peer_count, 0),
      total: Map.get(totals, :peer_count, 0)
    )
  end

  defp server_track_summary(call) do
    room = server_room(call)

    dgettext("group_call", "%{audio} audio / %{video} video / %{screen} screen",
      audio: Map.get(room, :audio_track_count, 0),
      video: Map.get(room, :video_track_count, 0),
      screen: Map.get(room, :screen_track_count, 0)
    )
  end

  defp server_fanout_summary(call) do
    totals = server_totals(call)

    dgettext("group_call", "%{subs} subs / %{routes} routes",
      subs: Map.get(totals, :subscriber_count, 0),
      routes: Map.get(totals, :outbound_peer_count, 0)
    )
  end

  defp server_rtp_summary(call, :inbound) do
    totals = server_totals(call)
    packets = Map.get(totals, :inbound_packets, 0)
    bytes = Map.get(totals, :inbound_bytes, 0)

    dgettext("group_call", "%{packets} pkt / %{bytes}",
      packets: packets,
      bytes: format_bytes(bytes)
    )
  end

  defp server_rtp_summary(call, :outbound) do
    totals = server_totals(call)
    packets = Map.get(totals, :outbound_packets, 0)
    bytes = Map.get(totals, :outbound_bytes, 0)

    dgettext("group_call", "%{packets} pkt / %{bytes}",
      packets: packets,
      bytes: format_bytes(bytes)
    )
  end

  defp server_ice_pair_summary(call) do
    totals = server_totals(call)

    dgettext("group_call", "%{nominated}/%{total} nominated",
      nominated: Map.get(totals, :nominated_pair_count, 0),
      total: Map.get(totals, :candidate_pair_count, 0)
    )
  end

  defp server_ice_traffic_summary(call) do
    totals = server_totals(call)

    dgettext("group_call", "%{sent} up / %{received} down",
      sent: format_bytes(Map.get(totals, :ice_bytes_sent, 0)),
      received: format_bytes(Map.get(totals, :ice_bytes_received, 0))
    )
  end

  defp server_feedback_summary(call) do
    totals = server_totals(call)

    dgettext("group_call", "NACK %{nack} / PLI %{pli}",
      nack: Map.get(totals, :nack_count, 0),
      pli: Map.get(totals, :pli_count, 0)
    )
  end

  defp peer_dom_id(peer) do
    peer
    |> field(:participant_id, field(peer, :nickname, "unknown"))
    |> to_string()
    |> String.replace(~r/[^a-zA-Z0-9_-]/, "-")
  end

  defp peer_label(peer) do
    nickname = field(peer, :nickname, "")
    participant_id = field(peer, :participant_id, nil)

    cond do
      is_binary(nickname) and nickname != "" ->
        nickname

      not is_nil(participant_id) ->
        dgettext("group_call", "Participant %{id}", id: participant_id)

      true ->
        dgettext("group_call", "Unknown peer")
    end
  end

  defp peer_state_summary(peer) do
    dgettext("group_call", "%{connection} / ICE %{ice}",
      connection: field(peer, :connection_state, "unknown"),
      ice: field(peer, :ice_connection_state, "unknown")
    )
  end

  defp peer_track_summary(peer) do
    dgettext("group_call", "%{inbound} in / %{fanout} fanout",
      inbound: field(peer, :inbound_track_count, 0),
      fanout: field(peer, :outbound_peer_count, 0)
    )
  end

  defp peer_rtp_summary(peer, key) do
    rtp = field(peer, key, %{})

    dgettext("group_call", "%{tracks} trk / %{packets} pkt / %{bytes}",
      tracks: field(rtp, :track_count, 0),
      packets: field(rtp, :packets, 0),
      bytes: format_bytes(field(rtp, :bytes, 0))
    )
  end

  defp peer_ice_pair_summary(peer) do
    pairs = field(peer, :candidate_pairs, %{})

    dgettext("group_call", "%{nominated}/%{total} nominated / %{valid} valid",
      nominated: field(pairs, :nominated, 0),
      total: field(pairs, :total, 0),
      valid: field(pairs, :valid, 0)
    )
  end

  defp peer_ice_traffic_summary(peer) do
    pairs = field(peer, :candidate_pairs, %{})

    dgettext("group_call", "%{sent} up / %{received} down",
      sent: format_bytes(field(pairs, :bytes_sent, 0)),
      received: format_bytes(field(pairs, :bytes_received, 0))
    )
  end

  defp peer_feedback_summary(peer) do
    inbound = field(peer, :inbound_rtp, %{})
    outbound = field(peer, :outbound_rtp, %{})

    dgettext("group_call", "NACK %{nack} / PLI %{pli}",
      nack: field(inbound, :nack_count, 0) + field(outbound, :nack_count, 0),
      pli: field(inbound, :pli_count, 0) + field(outbound, :pli_count, 0)
    )
  end

  defp server_participant_summary(%{participants: participants} = call)
       when is_list(participants) do
    connected = Enum.count(participants, &(Map.get(&1, :status) == "connected"))

    dgettext("group_call", "%{connected}/%{total} connected",
      connected: connected,
      total: participant_count(call, %{summary: %{participant_count: 0}})
    )
  end

  defp server_participant_summary(_call), do: dgettext("group_call", "0 connected")

  defp pending_participant_count(%{pending_participants: pending}) when is_list(pending),
    do: length(pending)

  defp pending_participant_count(_call), do: 0

  defp track_summary(%{tracks: tracks}, kind) when is_list(tracks) do
    matching = Enum.filter(tracks, &(Map.get(&1, :kind) == kind))
    active = Enum.count(matching, &(Map.get(&1, :status) == "active"))
    dgettext("group_call", "%{active}/%{total} active", active: active, total: length(matching))
  end

  defp track_summary(_call, _kind), do: dgettext("group_call", "0 active")

  defp screen_track_summary(%{tracks: tracks}) when is_list(tracks) do
    matching =
      Enum.filter(tracks, &(Map.get(&1, :kind) == "video" and Map.get(&1, :source) == "screen"))

    active = Enum.count(matching, &(Map.get(&1, :status) == "active"))
    dgettext("group_call", "%{active}/%{total} active", active: active, total: length(matching))
  end

  defp screen_track_summary(_call), do: dgettext("group_call", "0 active")

  defp connection_state(%{connection_state: state}, _stats) when is_binary(state) and state != "",
    do: state

  defp connection_state(_call, %{summary: %{connection_state: state}})
       when is_binary(state) and state != "",
       do: state

  defp connection_state(%{status: status}, _stats) when is_atom(status),
    do: Atom.to_string(status)

  defp connection_state(_call, _stats), do: dgettext("group_call", "Unknown")

  defp health_class("excellent"), do: "text-success"
  defp health_class("good"), do: "text-success"
  defp health_class("fair"), do: "text-warning"
  defp health_class("poor"), do: "text-destructive"
  defp health_class(_level), do: "text-muted-foreground"

  defp health_label("excellent"), do: dgettext("group_call", "Excellent")
  defp health_label("good"), do: dgettext("group_call", "Good")
  defp health_label("fair"), do: dgettext("group_call", "Fair")
  defp health_label("poor"), do: dgettext("group_call", "Poor")
  defp health_label(_level), do: dgettext("group_call", "Unknown")

  defp format_mos(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 1)
  defp format_mos(value) when is_integer(value), do: Integer.to_string(value)
  defp format_mos(_value), do: "0"

  defp format_bytes(bytes) when is_integer(bytes) and bytes >= 1_048_576 do
    value = bytes / 1_048_576
    "#{:erlang.float_to_binary(value, decimals: 1)} MB"
  end

  defp format_bytes(bytes) when is_integer(bytes) and bytes >= 1024 do
    value = bytes / 1024
    "#{:erlang.float_to_binary(value, decimals: 1)} KB"
  end

  defp format_bytes(bytes) when is_integer(bytes), do: "#{bytes} B"
  defp format_bytes(_bytes), do: "0 B"

  defp field(map, key, default) when is_map(map) and is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp field(_map, _key, default), do: default

  defp resolution_label(%{width: width, height: height}) when width > 0 and height > 0,
    do: "#{width}x#{height}"

  defp resolution_label(_video), do: dgettext("group_call", "No video")

  defp limitation_label("none"), do: dgettext("group_call", "None")
  defp limitation_label("cpu"), do: dgettext("group_call", "CPU")
  defp limitation_label("bandwidth"), do: dgettext("group_call", "Bandwidth")
  defp limitation_label("other"), do: dgettext("group_call", "Other")
  defp limitation_label(_reason), do: dgettext("group_call", "Unknown")
end
