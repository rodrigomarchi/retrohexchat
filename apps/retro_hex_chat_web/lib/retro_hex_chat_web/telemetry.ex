defmodule RetroHexChatWeb.Telemetry do
  use Gettext, backend: RetroHexChatWeb.Gettext
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary(dgettext("system", "phoenix.endpoint.start.system_time"),
        unit: {:native, :millisecond},
        reporter_options: [nav: dgettext("system", "HTTP")]
      ),
      summary(dgettext("system", "phoenix.endpoint.stop.duration"),
        unit: {:native, :millisecond},
        reporter_options: [nav: dgettext("system", "HTTP")]
      ),
      summary(dgettext("system", "phoenix.router_dispatch.start.system_time"),
        tags: [:route],
        unit: {:native, :millisecond},
        reporter_options: [nav: dgettext("system", "HTTP")]
      ),
      summary(dgettext("system", "phoenix.router_dispatch.exception.duration"),
        tags: [:route],
        unit: {:native, :millisecond},
        reporter_options: [nav: dgettext("system", "HTTP")]
      ),
      summary(dgettext("system", "phoenix.router_dispatch.stop.duration"),
        tags: [:route],
        unit: {:native, :millisecond},
        reporter_options: [nav: dgettext("system", "HTTP")]
      ),
      summary(dgettext("system", "phoenix.socket_connected.duration"),
        unit: {:native, :millisecond},
        reporter_options: [nav: dgettext("system", "HTTP")]
      ),
      sum(dgettext("system", "phoenix.socket_drain.count"),
        reporter_options: [nav: dgettext("system", "HTTP")]
      ),
      summary(dgettext("system", "phoenix.channel_joined.duration"),
        unit: {:native, :millisecond},
        reporter_options: [nav: dgettext("system", "HTTP")]
      ),
      summary(dgettext("system", "phoenix.channel_handled_in.duration"),
        tags: [:event],
        unit: {:native, :millisecond},
        reporter_options: [nav: dgettext("system", "HTTP")]
      ),

      # LiveView Metrics
      summary(dgettext("system", "phoenix.live_view.mount.stop.duration"),
        unit: {:native, :millisecond},
        tags: [:view],
        reporter_options: [nav: dgettext("system", "LiveView")]
      ),
      summary(dgettext("system", "phoenix.live_view.handle_event.stop.duration"),
        unit: {:native, :millisecond},
        tags: [:view, :event],
        reporter_options: [nav: dgettext("system", "LiveView")]
      ),
      summary(dgettext("system", "phoenix.live_view.handle_params.stop.duration"),
        unit: {:native, :millisecond},
        tags: [:view],
        reporter_options: [nav: dgettext("system", "LiveView")]
      ),

      # Database Metrics
      summary(dgettext("system", "retro_hex_chat.repo.query.total_time"),
        unit: {:native, :millisecond},
        description: dgettext("system", "The sum of the other measurements"),
        reporter_options: [nav: dgettext("system", "Database")]
      ),
      summary(dgettext("system", "retro_hex_chat.repo.query.decode_time"),
        unit: {:native, :millisecond},
        description:
          dgettext("system", "The time spent decoding the data received from the database"),
        reporter_options: [nav: dgettext("system", "Database")]
      ),
      summary(dgettext("system", "retro_hex_chat.repo.query.query_time"),
        unit: {:native, :millisecond},
        description: dgettext("system", "The time spent executing the query"),
        reporter_options: [nav: dgettext("system", "Database")]
      ),
      summary(dgettext("system", "retro_hex_chat.repo.query.queue_time"),
        unit: {:native, :millisecond},
        description: dgettext("system", "The time spent waiting for a database connection"),
        reporter_options: [nav: dgettext("system", "Database")]
      ),
      summary(dgettext("system", "retro_hex_chat.repo.query.idle_time"),
        unit: {:native, :millisecond},
        description:
          dgettext(
            "system",
            "The time the connection spent waiting before being checked out for the query"
          ),
        reporter_options: [nav: dgettext("system", "Database")]
      ),

      # Oban Metrics
      summary(dgettext("system", "oban.job.stop.duration"),
        event_name: [:oban, :job, :stop],
        measurement: :duration,
        tags: [:name, :queue, :state, :worker],
        tag_values: &oban_job_tags/1,
        unit: {:native, :millisecond},
        description: dgettext("system", "Background job processing duration"),
        reporter_options: [nav: dgettext("system", "Oban")]
      ),
      summary(dgettext("system", "oban.job.stop.queue_time"),
        event_name: [:oban, :job, :stop],
        measurement: :queue_time,
        tags: [:name, :queue, :state, :worker],
        tag_values: &oban_job_tags/1,
        unit: {:native, :millisecond},
        description: dgettext("system", "Time a background job waited before execution"),
        reporter_options: [nav: dgettext("system", "Oban")]
      ),
      summary(dgettext("system", "oban.job.exception.duration"),
        event_name: [:oban, :job, :exception],
        measurement: :duration,
        tags: [:name, :queue, :state, :worker, :kind],
        tag_values: &oban_exception_tags/1,
        unit: {:native, :millisecond},
        description: dgettext("system", "Failed background job processing duration"),
        reporter_options: [nav: dgettext("system", "Oban")]
      ),
      summary(dgettext("system", "oban.job.exception.queue_time"),
        event_name: [:oban, :job, :exception],
        measurement: :queue_time,
        tags: [:name, :queue, :state, :worker, :kind],
        tag_values: &oban_exception_tags/1,
        unit: {:native, :millisecond},
        description: dgettext("system", "Time a failed background job waited before execution"),
        reporter_options: [nav: dgettext("system", "Oban")]
      ),
      last_value(dgettext("system", "retro_hex_chat.prom_ex.oban.queue.length.count"),
        event_name: [:prom_ex, :plugin, :oban, :queue, :length, :count],
        measurement: :count,
        tags: [:name, :queue, :state],
        tag_values: &oban_queue_tags/1,
        description: dgettext("system", "Current Oban queue length by state"),
        reporter_options: [nav: dgettext("system", "Oban")]
      ),

      # VM Metrics
      summary(dgettext("system", "vm.memory.total"),
        unit: {:byte, :kilobyte},
        reporter_options: [nav: dgettext("system", "VM")]
      ),
      summary(dgettext("system", "vm.memory.processes"),
        unit: {:byte, :kilobyte},
        reporter_options: [nav: dgettext("system", "VM")]
      ),
      summary(dgettext("system", "vm.memory.binary"),
        unit: {:byte, :kilobyte},
        reporter_options: [nav: dgettext("system", "VM")]
      ),
      summary(dgettext("system", "vm.memory.ets"),
        unit: {:byte, :kilobyte},
        reporter_options: [nav: dgettext("system", "VM")]
      ),
      summary(dgettext("system", "vm.total_run_queue_lengths.total"),
        reporter_options: [nav: dgettext("system", "VM")]
      ),
      summary(dgettext("system", "vm.total_run_queue_lengths.cpu"),
        reporter_options: [nav: dgettext("system", "VM")]
      ),
      summary(dgettext("system", "vm.total_run_queue_lengths.io"),
        reporter_options: [nav: dgettext("system", "VM")]
      ),
      last_value(dgettext("system", "vm.system_counts.process_count"),
        reporter_options: [nav: dgettext("system", "VM")]
      ),
      last_value(dgettext("system", "vm.system_counts.atom_count"),
        reporter_options: [nav: dgettext("system", "VM")]
      ),
      last_value(dgettext("system", "vm.system_counts.port_count"),
        reporter_options: [nav: dgettext("system", "VM")]
      ),

      # Domain Metrics – Channels
      sum(dgettext("system", "retro_hex_chat.channels.channel_created.count"),
        tags: [:channel],
        description: dgettext("system", "Number of channels created"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.channels.channel_destroyed.count"),
        tags: [:channel],
        description: dgettext("system", "Number of channels destroyed"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.channels.mode_changed.count"),
        tags: [:channel],
        description: dgettext("system", "Number of channel mode changes"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.channels.topic_changed.count"),
        tags: [:channel],
        description: dgettext("system", "Number of channel topic changes"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.channels.active_count.value"),
        description: dgettext("system", "Number of active channel processes"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),

      # Domain Metrics – Presence
      sum(dgettext("system", "retro_hex_chat.presence.user_online.count"),
        tags: [:nickname, :channel],
        description: dgettext("system", "Number of user online events"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.presence.user_offline.count"),
        tags: [:nickname, :channel],
        description: dgettext("system", "Number of user offline events"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.presence.user_away.count"),
        tags: [:nickname],
        description: dgettext("system", "Number of user away toggles"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),

      # Domain Metrics – Virtual Spaces
      sum(dgettext("system", "retro_hex_chat.virtual_space.active_count.value"),
        description: dgettext("system", "Number of active virtual space processes"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      last_value(dgettext("system", "retro_hex_chat.virtual_space.participant_count.value"),
        tags: [:channel],
        description: dgettext("system", "Current virtual space participant count by channel"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.virtual_space.step.count"),
        tags: [:channel, :result, :reason],
        description: dgettext("system", "Number of virtual space movement steps"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      summary(dgettext("system", "retro_hex_chat.virtual_space.step.duration"),
        tags: [:channel, :result, :reason],
        unit: {:native, :millisecond},
        description: dgettext("system", "Virtual space movement input handling duration"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),

      # Domain Metrics – Group Calls
      last_value(dgettext("system", "retro_hex_chat.group_call.active_rooms.value"),
        description: dgettext("system", "Number of active group-call room processes"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      last_value(dgettext("system", "retro_hex_chat.group_call.active_peers.value"),
        description: dgettext("system", "Number of active group-call peer processes"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.group_call.join.count"),
        tags: [:result, :reason],
        description: dgettext("system", "Number of group-call join attempts"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.group_call.leave.count"),
        tags: [:status, :reason],
        description: dgettext("system", "Number of group-call participant leaves"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.group_call.track_added.count"),
        tags: [:kind, :source],
        description: dgettext("system", "Number of group-call media tracks announced"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.group_call.media_state.count"),
        tags: [:result, :reason],
        description: dgettext("system", "Number of group-call media state updates"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.group_call.media_moderated.count"),
        tags: [:result, :reason, :enabled],
        description: dgettext("system", "Number of group-call moderator media actions"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.group_call.participant_kicked.count"),
        tags: [:result, :reason],
        description: dgettext("system", "Number of group-call participant kick actions"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.group_call.room_closed.count"),
        tags: [:reason],
        description: dgettext("system", "Number of group-call rooms closed"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),

      # Domain Metrics – Call Recovery
      sum(dgettext("system", "retro_hex_chat.calls.recovery.transition.count"),
        tags: [:surface, :state, :reason, :trigger, :manual_retry],
        description:
          dgettext(
            "system",
            "Number of P2P and group-call recovery state transitions by reason"
          ),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.calls.client_error.count"),
        tags: [:surface, :code, :phase],
        description:
          dgettext("system", "Number of P2P and group-call client media/signaling errors"),
        reporter_options: [nav: dgettext("system", "Domain")]
      ),
      sum(dgettext("system", "retro_hex_chat.calls.signaling.replay.count"),
        tags: [:surface, :action, :reason],
        description: dgettext("system", "Number of P2P signaling replay outcomes"),
        reporter_options: [nav: dgettext("system", "Domain")]
      )
    ]
  end

  defp periodic_measurements do
    [
      {__MODULE__, :count_active_channels, []},
      {__MODULE__, :count_active_spaces, []},
      {__MODULE__, :count_active_group_calls, []},
      {__MODULE__, :count_active_group_call_peers, []}
    ]
  end

  defp oban_job_tags(%{job: %Oban.Job{} = job} = metadata) do
    %{
      name: oban_name(metadata),
      queue: job.queue,
      state: to_string(Map.get(metadata, :state, job.state)),
      worker: short_worker(job.worker)
    }
  end

  defp oban_exception_tags(metadata) do
    metadata
    |> oban_job_tags()
    |> Map.put(:kind, metadata |> Map.get(:kind, :unknown) |> to_string())
  end

  defp oban_queue_tags(metadata) do
    %{
      name: metadata |> Map.get(:name, Oban) |> inspect_name(),
      queue: metadata |> Map.get(:queue, :unknown) |> to_string(),
      state: metadata |> Map.get(:state, :unknown) |> to_string()
    }
  end

  defp oban_name(%{conf: %{name: name}}), do: inspect_name(name)
  defp oban_name(metadata), do: metadata |> Map.get(:name, Oban) |> inspect_name()

  defp inspect_name(name) when is_atom(name), do: inspect(name)
  defp inspect_name(name), do: to_string(name)

  defp short_worker(worker) when is_binary(worker) do
    worker
    |> String.trim_leading("Elixir.")
    |> String.split(".")
    |> List.last()
  end

  defp short_worker(worker), do: inspect(worker)

  @doc false
  def count_active_channels do
    %{active: active} =
      DynamicSupervisor.count_children(RetroHexChat.Channels.Supervisor)

    :telemetry.execute(
      [:retro_hex_chat, :channels, :active_count],
      %{value: active},
      %{}
    )
  end

  @doc false
  def count_active_spaces do
    %{active: active} =
      DynamicSupervisor.count_children(RetroHexChat.VirtualSpace.Supervisor)

    :telemetry.execute(
      [:retro_hex_chat, :virtual_space, :active_count],
      %{value: active},
      %{}
    )
  end

  @doc false
  def count_active_group_calls do
    %{active: active} =
      DynamicSupervisor.count_children(RetroHexChat.GroupCall.RoomSupervisor)

    :telemetry.execute(
      [:retro_hex_chat, :group_call, :active_rooms],
      %{value: active},
      %{}
    )
  end

  @doc false
  def count_active_group_call_peers do
    :telemetry.execute(
      [:retro_hex_chat, :group_call, :active_peers],
      %{value: Registry.count(RetroHexChat.GroupCall.PeerRegistry)},
      %{}
    )
  end
end
