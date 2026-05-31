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
      )
    ]
  end

  defp periodic_measurements do
    [
      {__MODULE__, :count_active_channels, []}
    ]
  end

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
end
