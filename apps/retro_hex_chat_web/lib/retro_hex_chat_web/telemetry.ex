defmodule RetroHexChatWeb.Telemetry do
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
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond},
        reporter_options: [nav: "HTTP"]
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond},
        reporter_options: [nav: "HTTP"]
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond},
        reporter_options: [nav: "HTTP"]
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond},
        reporter_options: [nav: "HTTP"]
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond},
        reporter_options: [nav: "HTTP"]
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond},
        reporter_options: [nav: "HTTP"]
      ),
      sum("phoenix.socket_drain.count",
        reporter_options: [nav: "HTTP"]
      ),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond},
        reporter_options: [nav: "HTTP"]
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond},
        reporter_options: [nav: "HTTP"]
      ),

      # LiveView Metrics
      summary("phoenix.live_view.mount.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view],
        reporter_options: [nav: "LiveView"]
      ),
      summary("phoenix.live_view.handle_event.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view, :event],
        reporter_options: [nav: "LiveView"]
      ),
      summary("phoenix.live_view.handle_params.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view],
        reporter_options: [nav: "LiveView"]
      ),

      # Database Metrics
      summary("retro_hex_chat.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements",
        reporter_options: [nav: "Database"]
      ),
      summary("retro_hex_chat.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database",
        reporter_options: [nav: "Database"]
      ),
      summary("retro_hex_chat.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query",
        reporter_options: [nav: "Database"]
      ),
      summary("retro_hex_chat.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection",
        reporter_options: [nav: "Database"]
      ),
      summary("retro_hex_chat.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query",
        reporter_options: [nav: "Database"]
      ),

      # VM Metrics
      summary("vm.memory.total",
        unit: {:byte, :kilobyte},
        reporter_options: [nav: "VM"]
      ),
      summary("vm.memory.processes",
        unit: {:byte, :kilobyte},
        reporter_options: [nav: "VM"]
      ),
      summary("vm.memory.binary",
        unit: {:byte, :kilobyte},
        reporter_options: [nav: "VM"]
      ),
      summary("vm.memory.ets",
        unit: {:byte, :kilobyte},
        reporter_options: [nav: "VM"]
      ),
      summary("vm.total_run_queue_lengths.total",
        reporter_options: [nav: "VM"]
      ),
      summary("vm.total_run_queue_lengths.cpu",
        reporter_options: [nav: "VM"]
      ),
      summary("vm.total_run_queue_lengths.io",
        reporter_options: [nav: "VM"]
      ),
      last_value("vm.system_counts.process_count",
        reporter_options: [nav: "VM"]
      ),
      last_value("vm.system_counts.atom_count",
        reporter_options: [nav: "VM"]
      ),
      last_value("vm.system_counts.port_count",
        reporter_options: [nav: "VM"]
      ),

      # Domain Metrics – Channels
      sum("retro_hex_chat.channels.channel_created.count",
        tags: [:channel],
        description: "Number of channels created",
        reporter_options: [nav: "Domain"]
      ),
      sum("retro_hex_chat.channels.channel_destroyed.count",
        tags: [:channel],
        description: "Number of channels destroyed",
        reporter_options: [nav: "Domain"]
      ),
      sum("retro_hex_chat.channels.mode_changed.count",
        tags: [:channel],
        description: "Number of channel mode changes",
        reporter_options: [nav: "Domain"]
      ),
      sum("retro_hex_chat.channels.topic_changed.count",
        tags: [:channel],
        description: "Number of channel topic changes",
        reporter_options: [nav: "Domain"]
      ),
      sum("retro_hex_chat.channels.active_count.value",
        description: "Number of active channel processes",
        reporter_options: [nav: "Domain"]
      ),

      # Domain Metrics – Presence
      sum("retro_hex_chat.presence.user_online.count",
        tags: [:nickname, :channel],
        description: "Number of user online events",
        reporter_options: [nav: "Domain"]
      ),
      sum("retro_hex_chat.presence.user_offline.count",
        tags: [:nickname, :channel],
        description: "Number of user offline events",
        reporter_options: [nav: "Domain"]
      ),
      sum("retro_hex_chat.presence.user_away.count",
        tags: [:nickname],
        description: "Number of user away toggles",
        reporter_options: [nav: "Domain"]
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
