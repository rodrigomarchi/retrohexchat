defmodule RetroHexChat.SystemInfo.Runtime do
  @moduledoc """
  The node's own vital signs: what it is, and how hard it is currently working.

  Split in two because the halves change on different clocks. `info/1` describes
  the build — emulator banner, architecture, library versions, the ceilings
  compiled into this VM — and is fixed for the lifetime of the node. `usage/0`
  is the reading a monitor refreshes: counts against those ceilings, uptime, IO
  totals, scheduler backlog and the memory split.

  Reporting a version means asking the application controller for a loaded
  application's `vsn`, so the caller names which applications matter rather than
  this module hardcoding a web framework it has no business knowing about.
  """

  alias RetroHexChat.SystemInfo.{Memory, Usage}

  defmodule Info do
    @moduledoc "The fixed description of a running node."

    @type version :: %{app: atom(), version: String.t()}

    @type t :: %__MODULE__{
            banner: String.t(),
            architecture: String.t(),
            versions: [version()],
            atom_limit: pos_integer(),
            port_limit: pos_integer(),
            process_limit: pos_integer()
          }

    @enforce_keys [
      :banner,
      :architecture,
      :versions,
      :atom_limit,
      :port_limit,
      :process_limit
    ]
    defstruct [:banner, :architecture, :versions, :atom_limit, :port_limit, :process_limit]
  end

  defmodule Snapshot do
    @moduledoc "One reading of how hard the node is working."

    alias RetroHexChat.SystemInfo.{Memory, Usage}

    @type t :: %__MODULE__{
            atoms: Usage.t(),
            ports: Usage.t(),
            processes: Usage.t(),
            uptime_ms: non_neg_integer(),
            input_bytes: non_neg_integer(),
            output_bytes: non_neg_integer(),
            total_run_queue: non_neg_integer(),
            cpu_run_queue: non_neg_integer(),
            io_run_queue: non_neg_integer(),
            memory: Memory.t()
          }

    @enforce_keys [
      :atoms,
      :ports,
      :processes,
      :uptime_ms,
      :input_bytes,
      :output_bytes,
      :total_run_queue,
      :cpu_run_queue,
      :io_run_queue,
      :memory
    ]
    defstruct [
      :atoms,
      :ports,
      :processes,
      :uptime_ms,
      :input_bytes,
      :output_bytes,
      :total_run_queue,
      :cpu_run_queue,
      :io_run_queue,
      :memory
    ]
  end

  @doc """
  Describes the node, reporting the version of each application in `apps`.

  An application that is not loaded reports as `nil` rather than being dropped,
  because a missing dependency is itself worth seeing on a diagnostics screen.
  """
  @spec info([atom()]) :: Info.t()
  def info(apps \\ []) when is_list(apps) do
    %Info{
      banner: to_string(:erlang.system_info(:system_version)),
      architecture: to_string(:erlang.system_info(:system_architecture)),
      versions: Enum.map(apps, &version/1),
      atom_limit: :erlang.system_info(:atom_limit),
      port_limit: :erlang.system_info(:port_limit),
      process_limit: :erlang.system_info(:process_limit)
    }
  end

  @doc """
  Reads how hard the node is working right now.

  The IO run queue is not reported directly by the emulator: it is the
  difference between the all-schedulers figure and the CPU-only one, which is
  why both statistics are read rather than just the total.
  """
  @spec usage() :: Snapshot.t()
  def usage do
    {{:input, input}, {:output, output}} = :erlang.statistics(:io)

    total_run_queue = :erlang.statistics(:total_run_queue_lengths_all)
    cpu_run_queue = :erlang.statistics(:total_run_queue_lengths)

    # The two figures are separate samples, and work queues up between them, so
    # on a busy node the second can exceed the first and their difference go
    # negative. The emulator offers no way to read both at one instant, so what
    # is reported is a floor: never fewer than none waiting.
    io_run_queue = max(total_run_queue - cpu_run_queue, 0)

    %Snapshot{
      atoms: Usage.new(:erlang.system_info(:atom_count), :erlang.system_info(:atom_limit)),
      ports: Usage.new(:erlang.system_info(:port_count), :erlang.system_info(:port_limit)),
      processes:
        Usage.new(:erlang.system_info(:process_count), :erlang.system_info(:process_limit)),
      uptime_ms: :erlang.statistics(:wall_clock) |> elem(0),
      input_bytes: input,
      output_bytes: output,
      total_run_queue: total_run_queue,
      cpu_run_queue: cpu_run_queue,
      io_run_queue: io_run_queue,
      memory: Memory.current()
    }
  end

  @doc "The Elixir version this node runs, reported like any other dependency."
  @spec elixir_version() :: String.t()
  def elixir_version, do: System.version()

  defp version(app) do
    %{app: app, version: loaded_version(app)}
  end

  defp loaded_version(:elixir), do: System.version()

  defp loaded_version(app) do
    case Application.spec(app, :vsn) do
      nil -> nil
      vsn -> to_string(vsn)
    end
  end
end
