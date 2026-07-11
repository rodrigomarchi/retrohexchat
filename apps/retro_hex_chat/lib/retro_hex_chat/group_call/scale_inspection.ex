defmodule RetroHexChat.GroupCall.ScaleInspection do
  @moduledoc """
  Local scale inspection helpers for group-call fanout and signaling payloads.

  This module does not start browsers or WebRTC connections. It keeps a cheap,
  deterministic BEAM-side model of the expected N:N fanout graph and payload
  shape so F4/F5 changes have a repeatable baseline before the dedicated
  multi-browser load window.
  """

  alias RetroHexChat.GroupCall.Registry

  @default_participant_counts [2, 3, 10, 25, 50, 100]
  @default_tracks_per_participant 2
  @process_info_keys [
    :memory,
    :message_queue_len,
    :reductions,
    :status,
    :current_function,
    :heap_size,
    :total_heap_size,
    :stack_size
  ]

  @type fanout_route :: %{
          publisher_id: pos_integer(),
          subscriber_id: pos_integer(),
          kind: String.t(),
          source: String.t()
        }

  @type payload_sizes :: %{atom() => non_neg_integer()}

  @type participant_result :: %{
          participant_count: pos_integer(),
          tracks_per_participant: pos_integer(),
          fanout: %{
            route_count: non_neg_integer(),
            expected_route_count: non_neg_integer(),
            build_time_us: non_neg_integer(),
            reductions: non_neg_integer()
          },
          payload_bytes: payload_sizes(),
          largest_payload: {atom(), non_neg_integer()}
        }

  @type peer_process_sample :: %{
          key: term(),
          pid: String.t(),
          memory_bytes: non_neg_integer(),
          message_queue_len: non_neg_integer(),
          reductions: non_neg_integer(),
          status: term(),
          current_function: term(),
          heap_size: non_neg_integer(),
          total_heap_size: non_neg_integer(),
          stack_size: non_neg_integer()
        }

  @spec run([pos_integer()], keyword()) :: %{
          generated_at: DateTime.t(),
          participant_results: [participant_result()],
          peer_processes: [peer_process_sample()]
        }
  def run(participant_counts \\ @default_participant_counts, opts \\ []) do
    tracks_per_participant =
      Keyword.get(opts, :tracks_per_participant, @default_tracks_per_participant)

    %{
      generated_at: DateTime.utc_now(),
      participant_results:
        Enum.map(participant_counts, &inspect_participant_count(&1, tracks_per_participant)),
      peer_processes: sample_peer_processes()
    }
  end

  @spec inspect_participant_count(pos_integer(), pos_integer()) :: participant_result()
  def inspect_participant_count(
        participant_count,
        tracks_per_participant \\ @default_tracks_per_participant
      )
      when is_integer(participant_count) and participant_count > 0 and
             is_integer(tracks_per_participant) and tracks_per_participant > 0 do
    reductions_before = process_reductions()

    {build_time_us, fanout_routes} =
      :timer.tc(fn -> fanout_plan(participant_count, tracks_per_participant) end)

    reductions = process_reductions() - reductions_before
    payload_bytes = payload_sizes(participant_count, tracks_per_participant)

    %{
      participant_count: participant_count,
      tracks_per_participant: tracks_per_participant,
      fanout: %{
        route_count: length(fanout_routes),
        expected_route_count: expected_route_count(participant_count, tracks_per_participant),
        build_time_us: build_time_us,
        reductions: max(reductions, 0)
      },
      payload_bytes: payload_bytes,
      largest_payload: Enum.max_by(payload_bytes, fn {_event, bytes} -> bytes end)
    }
  end

  @spec fanout_plan(pos_integer(), pos_integer()) :: [fanout_route()]
  def fanout_plan(participant_count, tracks_per_participant \\ @default_tracks_per_participant)
      when is_integer(participant_count) and participant_count > 0 and
             is_integer(tracks_per_participant) and tracks_per_participant > 0 do
    participants = Enum.to_list(1..participant_count)
    track_templates = track_templates(tracks_per_participant)

    for publisher_id <- participants,
        subscriber_id <- participants,
        publisher_id != subscriber_id,
        track <- track_templates do
      %{
        publisher_id: publisher_id,
        subscriber_id: subscriber_id,
        kind: track.kind,
        source: track.source
      }
    end
  end

  @spec expected_route_count(pos_integer(), pos_integer()) :: non_neg_integer()
  def expected_route_count(participant_count, tracks_per_participant)
      when participant_count > 0 and tracks_per_participant > 0 do
    participant_count * max(participant_count - 1, 0) * tracks_per_participant
  end

  @spec payload_sizes(pos_integer(), pos_integer()) :: payload_sizes()
  def payload_sizes(participant_count, tracks_per_participant \\ @default_tracks_per_participant)
      when is_integer(participant_count) and participant_count > 0 and
             is_integer(tracks_per_participant) and tracks_per_participant > 0 do
    participant_payloads = participants(participant_count)
    track_payloads = tracks(participant_count, tracks_per_participant)
    last_participant = List.last(participant_payloads)
    last_track = List.last(track_payloads)

    %{
      summary: %{
        room: room_payload(participant_count),
        participants: participant_payloads,
        pending_participants: [],
        tracks: track_payloads
      },
      peer_joined: %{participant: last_participant},
      peer_left: %{participant_id: last_participant.id, reason: "left"},
      track_added: %{participant_id: last_participant.id, track: last_track},
      track_updated: %{participant_id: last_participant.id, track: last_track},
      track_removed: %{track_id: last_track.id},
      media_state: %{participant: last_participant}
    }
    |> Map.new(fn {event, payload} -> {event, payload_size(payload)} end)
  end

  @spec sample_peer_processes() :: [peer_process_sample()]
  def sample_peer_processes do
    registry_name = Registry.peer_registry_name()

    if Process.whereis(registry_name) do
      registry_name
      |> Elixir.Registry.select([{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
      |> Enum.map(&process_sample/1)
    else
      []
    end
  end

  defp process_sample({key, pid}) do
    info = Process.info(pid, @process_info_keys) || []

    %{
      key: key,
      pid: Kernel.inspect(pid),
      memory_bytes: Keyword.get(info, :memory, 0),
      message_queue_len: Keyword.get(info, :message_queue_len, 0),
      reductions: Keyword.get(info, :reductions, 0),
      status: Keyword.get(info, :status),
      current_function: Keyword.get(info, :current_function),
      heap_size: Keyword.get(info, :heap_size, 0),
      total_heap_size: Keyword.get(info, :total_heap_size, 0),
      stack_size: Keyword.get(info, :stack_size, 0)
    }
  end

  defp process_reductions do
    self()
    |> Process.info(:reductions)
    |> elem(1)
  end

  defp payload_size(payload), do: payload |> Jason.encode!() |> byte_size()

  defp room_payload(participant_count) do
    %{
      id: 1,
      token: "scale-inspection-token",
      channel_name: "#scale",
      status: "active",
      max_participants: max(participant_count, 100)
    }
  end

  defp participants(participant_count) do
    Enum.map(1..participant_count, fn id ->
      %{
        id: id,
        nickname: "user#{id}",
        status: "connected",
        media_state: %{"audio" => true, "video" => true},
        channel_role_snapshot: "regular"
      }
    end)
  end

  defp tracks(participant_count, tracks_per_participant) do
    for participant_id <- 1..participant_count,
        {track, index} <- Enum.with_index(track_templates(tracks_per_participant), 1) do
      %{
        id: participant_id * 100 + index,
        participant_id: participant_id,
        kind: track.kind,
        source: track.source,
        status: "active",
        webrtc_track_id: "track-#{participant_id}-#{track.source}",
        stream_id: "stream-#{participant_id}"
      }
    end
  end

  defp track_templates(tracks_per_participant) do
    base = [
      %{kind: "audio", source: "microphone"},
      %{kind: "video", source: "camera"}
    ]

    extra =
      if tracks_per_participant > length(base) do
        for index <- 1..(tracks_per_participant - length(base)) do
          %{kind: "video", source: "extra_#{index}"}
        end
      else
        []
      end

    (base ++ extra)
    |> Enum.take(tracks_per_participant)
  end
end
