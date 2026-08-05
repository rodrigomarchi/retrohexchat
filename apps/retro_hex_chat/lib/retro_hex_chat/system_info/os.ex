defmodule RetroHexChat.SystemInfo.OS do
  @moduledoc """
  What the machine underneath the VM reports about itself.

  Everything else in `SystemInfo` describes the emulator's own accounting,
  which is blind to its neighbours: a node can look healthy while the host it
  shares is out of memory or pinned by another tenant. These readings come from
  `:os_mon` and are the outside view.

  Every field is optional. `:os_mon` reports different subsets per platform —
  disk data is absent on some, CPU utilisation on others — and a monitor that
  crashed because one gauge was unavailable would be worse than one that draws
  the gauges it has. Absence is reported as `nil` and rendered as unavailable.

  `cpu_util` is a delta since the previous call, so the first reading after
  boot is meaningless by construction; callers should treat it as a warm-up.
  """

  @type t :: %__MODULE__{
          cpu_avg1: float() | nil,
          cpu_avg5: float() | nil,
          cpu_avg15: float() | nil,
          cpu_util: float() | nil,
          logical_processors: non_neg_integer() | nil,
          os_process_count: non_neg_integer() | nil,
          total_memory: non_neg_integer() | nil,
          free_memory: non_neg_integer() | nil,
          used_memory: non_neg_integer() | nil,
          disks: [disk()]
        }

  @type disk :: %{
          mount: String.t(),
          total_kb: non_neg_integer(),
          percent_used: non_neg_integer()
        }

  defstruct cpu_avg1: nil,
            cpu_avg5: nil,
            cpu_avg15: nil,
            cpu_util: nil,
            logical_processors: nil,
            os_process_count: nil,
            total_memory: nil,
            free_memory: nil,
            used_memory: nil,
            disks: []

  @doc "Reads every gauge the host makes available."
  @spec current() :: t()
  def current do
    memory = system_memory()

    %__MODULE__{
      cpu_avg1: normalized_avg(&:cpu_sup.avg1/0),
      cpu_avg5: normalized_avg(&:cpu_sup.avg5/0),
      cpu_avg15: normalized_avg(&:cpu_sup.avg15/0),
      cpu_util: cpu_util(),
      logical_processors: logical_processors(),
      os_process_count: guarded(&:cpu_sup.nprocs/0),
      total_memory: memory[:total_memory],
      free_memory: memory[:free_memory],
      used_memory: used_memory(memory),
      disks: disks()
    }
  end

  @doc "Whether `:os_mon` is running and able to answer at all."
  @spec available?() :: boolean()
  def available?, do: is_pid(Process.whereis(:os_mon_sup))

  # `:cpu_sup.nprocs/0` counts processes running on the host, not processors —
  # the CPU count comes from the emulator, which is the figure a load average
  # has to be read against.
  defp logical_processors do
    case :erlang.system_info(:logical_processors_available) do
      count when is_integer(count) -> count
      _unknown -> nil
    end
  end

  # :cpu_sup reports load average scaled by 256 so it can return an integer.
  defp normalized_avg(fun) do
    case guarded(fun) do
      nil -> nil
      value -> value / 256
    end
  end

  defp cpu_util do
    case guarded(&:cpu_sup.util/0) do
      value when is_float(value) -> value
      value when is_integer(value) -> value * 1.0
      _other -> nil
    end
  end

  defp system_memory do
    case guarded(&:memsup.get_system_memory_data/0) do
      data when is_list(data) -> data
      _other -> []
    end
  end

  # Some platforms report available memory instead of free; neither is present
  # on all of them, so the derived figure is only offered when both halves are.
  defp used_memory(memory) do
    with total when is_integer(total) <- memory[:total_memory],
         free when is_integer(free) <- memory[:free_memory] do
      total - free
    else
      _other -> nil
    end
  end

  defp disks do
    case guarded(&:disksup.get_disk_data/0) do
      data when is_list(data) -> Enum.flat_map(data, &disk/1)
      _other -> []
    end
  end

  # A platform with no disk data answers with a single placeholder entry.
  defp disk({~c"none", _total, _percent}), do: []

  defp disk({mount, total_kb, percent_used}) do
    [%{mount: to_string(mount), total_kb: total_kb, percent_used: percent_used}]
  end

  defp disk(_other), do: []

  # :os_mon is optional and platform-dependent: a gauge it cannot provide
  # raises or exits rather than returning an error, and that is not a fault.
  defp guarded(fun) do
    fun.()
  rescue
    _error -> nil
  catch
    :exit, _reason -> nil
  end
end
