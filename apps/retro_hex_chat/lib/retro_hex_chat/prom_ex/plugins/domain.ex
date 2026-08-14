defmodule RetroHexChat.PromEx.Plugins.Domain do
  @moduledoc """
  PromEx metrics for RetroHexChat product/domain telemetry.
  """

  use PromEx.Plugin

  @generic_stop [:retro_hex_chat, :observability, :operation, :stop]
  @generic_exception [:retro_hex_chat, :observability, :operation, :exception]
  @generic_counter [:retro_hex_chat, :observability, :operation, :counter]
  @generic_value [:retro_hex_chat, :observability, :operation, :value]
  @chat_send_stop [:retro_hex_chat, :chat, :message, :send, :stop]
  @chat_receive_stop [:retro_hex_chat, :chat, :message, :receive, :stop]
  @chat_broadcast_stop [:retro_hex_chat, :chat, :message, :broadcast, :stop]
  @command_dispatch_stop [:retro_hex_chat, :commands, :dispatch, :stop]
  @call_recovery_transition [:retro_hex_chat, :calls, :recovery, :transition]
  @call_client_error [:retro_hex_chat, :calls, :client_error]
  @call_signaling_replay [:retro_hex_chat, :calls, :signaling, :replay]
  @game_session_sample [:retro_hex_chat, :games, :session, :sample]
  @chat_auto_ignore [:retro_hex_chat, :chat, :auto_ignore]

  @impl true
  def event_metrics(opts) do
    metric_prefix = Keyword.get(opts, :metric_prefix, [:retro_hex_chat, :domain])

    Event.build(
      :retro_hex_chat_domain_event_metrics,
      [
        counter(
          metric_prefix ++ [:operations, :total],
          event_name: @generic_stop,
          description: "Total number of instrumented domain operations.",
          tag_values: &operation_tags/1,
          tags: [:context, :operation, :result]
        ),
        distribution(
          metric_prefix ++ [:operation, :duration, :milliseconds],
          event_name: @generic_stop,
          measurement: :duration,
          description: "Duration of instrumented domain operations.",
          reporter_options: [buckets: duration_buckets()],
          tag_values: &operation_tags/1,
          tags: [:context, :operation, :result],
          unit: {:native, :millisecond}
        ),
        counter(
          metric_prefix ++ [:operation, :counter, :total],
          event_name: @generic_counter,
          measurement: :value,
          description: "Total business counts emitted by instrumented domain operations.",
          tag_values: &operation_measurement_tags/1,
          tags: [:context, :operation, :result, :measurement]
        ),
        last_value(
          metric_prefix ++ [:operation, :value],
          event_name: @generic_value,
          measurement: :value,
          description: "Latest business values emitted by instrumented domain operations.",
          tag_values: &operation_measurement_tags/1,
          tags: [:context, :operation, :result, :measurement]
        ),
        counter(
          metric_prefix ++ [:operation, :exceptions, :total],
          event_name: @generic_exception,
          description: "Total number of exceptions in instrumented domain operations.",
          tag_values: &exception_tags/1,
          tags: [:context, :operation, :kind]
        ),
        distribution(
          metric_prefix ++ [:chat, :message, :send, :duration, :milliseconds],
          event_name: @chat_send_stop,
          measurement: :duration,
          description: "Chat message send duration.",
          reporter_options: [buckets: duration_buckets()],
          tag_values: &message_tags/1,
          tags: [:conversation_type, :message_type, :result],
          unit: {:native, :millisecond}
        ),
        distribution(
          metric_prefix ++ [:chat, :message, :receive, :duration, :milliseconds],
          event_name: @chat_receive_stop,
          measurement: :duration,
          description: "LiveView PubSub message receive/render preparation duration.",
          reporter_options: [buckets: duration_buckets()],
          tag_values: &receive_tags/1,
          tags: [:conversation_type, :message_type, :active_context, :result],
          unit: {:native, :millisecond}
        ),
        distribution(
          metric_prefix ++ [:chat, :message, :broadcast, :duration, :milliseconds],
          event_name: @chat_broadcast_stop,
          measurement: :duration,
          description: "Chat PubSub broadcast duration.",
          reporter_options: [buckets: duration_buckets()],
          tag_values: &broadcast_tags/1,
          tags: [:conversation_type, :message_type, :event, :result],
          unit: {:native, :millisecond}
        ),
        distribution(
          metric_prefix ++ [:chat, :message, :size, :bytes],
          event_name: @chat_send_stop,
          measurement: fn _measurements, metadata -> Map.get(metadata, :message_size_bytes, 0) end,
          description: "Chat message payload size in bytes.",
          reporter_options: [buckets: [0, 64, 256, 1_024, 4_096, 16_384]],
          tag_values: &message_tags/1,
          tags: [:conversation_type, :message_type, :result],
          unit: :byte
        ),
        distribution(
          metric_prefix ++ [:commands, :dispatch, :duration, :milliseconds],
          event_name: @command_dispatch_stop,
          measurement: :duration,
          description: "Command dispatch duration.",
          reporter_options: [buckets: duration_buckets()],
          tag_values: &command_tags/1,
          tags: [:command, :result],
          unit: {:native, :millisecond}
        ),
        # Auto-ignore is decided in one reader's session and never reaches the
        # sender, so without this a bot can be silenced across the server with
        # nothing to show for it. `kind` separates our defect from moderation
        # doing its job; the reader is deliberately not a tag.
        counter(
          metric_prefix ++ [:chat, :auto_ignores, :total],
          event_name: @chat_auto_ignore,
          description: "Total number of senders auto-ignored for flooding, by reader session.",
          tag_values: &auto_ignore_tags/1,
          tags: [:sender, :kind, :surface]
        ),
        counter(
          metric_prefix ++ [:calls, :recovery, :transitions, :total],
          event_name: @call_recovery_transition,
          description: "Total number of P2P and group-call recovery state transitions.",
          tag_values: &call_recovery_tags/1,
          tags: [:surface, :state, :reason, :trigger, :manual_retry]
        ),
        counter(
          metric_prefix ++ [:calls, :client, :errors, :total],
          event_name: @call_client_error,
          description: "Total number of P2P and group-call client-side media/signaling errors.",
          tag_values: &call_error_tags/1,
          tags: [:surface, :code, :phase]
        ),
        counter(
          metric_prefix ++ [:calls, :signaling, :replay, :total],
          event_name: @call_signaling_replay,
          description: "Total number of P2P signaling replay outcomes.",
          tag_values: &call_replay_tags/1,
          tags: [:surface, :action, :reason]
        ),

        # P2P games. Game state never reaches the server, so these are reported
        # by the two browsers playing the match. `role` is the tag that matters:
        # the host simulates and the guest draws, and a match going wrong shows
        # up as the two roles disagreeing about how the same match went.
        counter(
          metric_prefix ++ [:games, :session, :samples, :total],
          event_name: @game_session_sample,
          description: "Total number of P2P game telemetry samples, by health verdict.",
          tag_values: &game_session_tags/1,
          tags: [:game_id, :role, :health, :channel_state]
        ),
        distribution(
          metric_prefix ++ [:games, :session, :render_fps],
          event_name: @game_session_sample,
          measurement: :render_fps,
          description: "Frames per second drawn during a P2P game.",
          reporter_options: [buckets: frame_rate_buckets()],
          tag_values: &game_role_tags/1,
          tags: [:game_id, :role]
        ),
        distribution(
          metric_prefix ++ [:games, :session, :state_gap, :milliseconds],
          event_name: @game_session_sample,
          measurement: :state_gap_p95_ms,
          description: "95th percentile gap between authoritative game snapshots.",
          reporter_options: [buckets: duration_buckets()],
          tag_values: &game_role_tags/1,
          tags: [:game_id, :role]
        ),
        distribution(
          metric_prefix ++ [:games, :session, :rtt, :milliseconds],
          event_name: @game_session_sample,
          measurement: :rtt_ms,
          description: "Peer connection round-trip time during a P2P game.",
          reporter_options: [buckets: duration_buckets()],
          tag_values: &game_role_tags/1,
          tags: [:game_id, :role]
        ),
        sum(
          metric_prefix ++ [:games, :session, :state_drops, :total],
          event_name: @game_session_sample,
          measurement: :send_dropped,
          description: "Game snapshots skipped because the data channel was backed up.",
          tag_values: &game_role_tags/1,
          tags: [:game_id, :role]
        ),
        sum(
          metric_prefix ++ [:games, :session, :stalls, :total],
          event_name: @game_session_sample,
          measurement: :stall_count,
          description: "Frames whose simulation backlog exceeded the catch-up cap.",
          tag_values: &game_role_tags/1,
          tags: [:game_id, :role]
        )
      ]
    )
  end

  defp operation_tags(metadata) do
    %{
      context: tag(metadata, :context),
      operation: tag(metadata, :operation),
      result: tag(metadata, :result, "ok")
    }
  end

  defp exception_tags(metadata) do
    metadata
    |> operation_tags()
    |> Map.put(:kind, tag(metadata, :kind, "error"))
  end

  defp operation_measurement_tags(metadata) do
    metadata
    |> operation_tags()
    |> Map.put(:measurement, tag(metadata, :measurement))
  end

  defp message_tags(metadata) do
    %{
      conversation_type: tag(metadata, :conversation_type),
      message_type: tag(metadata, :message_type),
      result: tag(metadata, :result, "ok")
    }
  end

  defp receive_tags(metadata) do
    metadata
    |> message_tags()
    |> Map.put(:active_context, tag(metadata, :active_context, "unknown"))
  end

  defp broadcast_tags(metadata) do
    metadata
    |> message_tags()
    |> Map.put(:event, tag(metadata, :event, "unknown"))
  end

  defp command_tags(metadata) do
    %{
      command: tag(metadata, :command),
      result: tag(metadata, :result, "ok")
    }
  end

  defp call_recovery_tags(metadata) do
    %{
      surface: tag(metadata, :surface),
      state: tag(metadata, :state),
      reason: tag(metadata, :reason),
      trigger: tag(metadata, :trigger),
      manual_retry: tag(metadata, :manual_retry, "false")
    }
  end

  defp call_error_tags(metadata) do
    %{
      surface: tag(metadata, :surface),
      code: tag(metadata, :code),
      phase: tag(metadata, :phase)
    }
  end

  defp auto_ignore_tags(metadata) do
    %{
      sender: tag(metadata, :sender),
      kind: tag(metadata, :kind),
      surface: tag(metadata, :surface)
    }
  end

  defp call_replay_tags(metadata) do
    %{
      surface: tag(metadata, :surface),
      action: tag(metadata, :action),
      reason: tag(metadata, :reason)
    }
  end

  defp game_role_tags(metadata) do
    %{
      game_id: tag(metadata, :game_id),
      role: tag(metadata, :role)
    }
  end

  defp game_session_tags(metadata) do
    metadata
    |> game_role_tags()
    |> Map.put(:health, tag(metadata, :health))
    |> Map.put(:channel_state, tag(metadata, :channel_state))
  end

  defp tag(metadata, key, default \\ "unknown") do
    case Map.get(metadata, key, default) do
      nil -> default
      "" -> default
      value when is_atom(value) -> Atom.to_string(value)
      value when is_binary(value) -> value
      value when is_boolean(value) -> to_string(value)
      value when is_integer(value) -> Integer.to_string(value)
      _value -> default
    end
  end

  defp duration_buckets do
    [1, 5, 10, 25, 50, 100, 250, 500, 1_000, 2_500, 5_000, 10_000, 30_000]
  end

  # Bucketed around what a player notices: below 30 is visibly rough, 60 is the
  # simulation rate, and above that is a high-refresh display keeping up.
  defp frame_rate_buckets do
    [10, 20, 30, 45, 55, 60, 75, 90, 120, 144, 240]
  end
end
