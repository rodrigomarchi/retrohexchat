defmodule RetroHexChat.SystemInfo.Allocators do
  @moduledoc """
  What each of the emulator's memory allocators is holding.

  The VM does not ask the OS for memory per object; it acquires large carriers
  and cuts blocks out of them. The gap between the two is the number that
  matters: blocks are what the program actually asked for, carriers are what
  the node is holding from the operating system. A wide and growing gap is
  fragmentation — memory the node will not release and cannot reuse — and it is
  invisible to `:erlang.memory/0`, which reports only the block side.

  The shape of `allocator_sizes` has changed across OTP releases: block sizes
  used to be a single triple and are now itemised per allocation type. Both
  shapes are folded here, so the reading survives an upgrade rather than
  silently reporting zero.

  Implements `RetroHexChat.SystemInfo.Source`, because a list of allocators
  ordered by size is the same interaction as a list of processes ordered by
  size — which is what lets the allocator window be the listing window handed
  a different population, rather than a screen of its own.
  """

  use Gettext, backend: RetroHexChat.Gettext

  @behaviour RetroHexChat.SystemInfo.Source

  alias RetroHexChat.Admin.Table
  alias RetroHexChat.SystemInfo.Query

  @type t :: %{
          name: atom(),
          block_size: non_neg_integer(),
          carrier_size: non_neg_integer(),
          max_carrier_size: non_neg_integer()
        }

  @impl true
  @doc "Columns describing an allocator reading."
  @spec columns() :: [Table.column()]
  def columns do
    [
      Table.column(:name, dgettext("admin", "Allocator"), sortable: true),
      Table.column(:block_size, dgettext("admin", "Block size"),
        format: :bytes,
        sortable: true
      ),
      Table.column(:carrier_size, dgettext("admin", "Carrier size"),
        format: :bytes,
        sortable: true
      ),
      Table.column(:max_carrier_size, dgettext("admin", "Peak carrier size"),
        format: :bytes,
        sortable: true
      ),
      Table.column(:utilisation, dgettext("admin", "In use"), format: :percent, sortable: true)
    ]
  end

  @impl true
  @spec default_sort() :: atom()
  def default_sort, do: :carrier_size

  @impl true
  @spec rows(Query.t()) :: [map()]
  def rows(%Query{search: search}) do
    Enum.filter(current(), &Query.matches?(search, [&1.name]))
  end

  @doc """
  Reads every allocator, with a synthetic total row first.

  The total leads because the per-allocator breakdown only means something
  against it, and a reader scanning for a fragmentation problem starts by
  comparing the two aggregate figures.
  """
  @spec current() :: [t()]
  def current do
    allocators = :erlang.system_info(:alloc_util_allocators)

    readings =
      {:allocator_sizes, allocators}
      |> :erlang.system_info()
      |> Enum.map(&reading/1)

    [total(readings) | readings]
  end

  defp reading({name, instances}) do
    {block, carrier, max_carrier} =
      Enum.reduce(instances, {0, 0, 0}, fn instance, acc ->
        add(acc, instance_sizes(instance))
      end)

    reading(to_string(name), name, block, carrier, max_carrier)
  end

  defp instance_sizes({:instance, _number, properties}) do
    Enum.reduce(properties, {0, 0, 0}, fn property, acc ->
      add(acc, carrier_sizes(property))
    end)
  end

  defp instance_sizes(_other), do: {0, 0, 0}

  # Only the carrier categories carry sizes; the rest of an instance's
  # properties describe calls and options.
  defp carrier_sizes({category, values}) when category in [:mbcs, :mbcs_pool, :sbcs] do
    carriers = find(values, :carriers_size)

    {blocks_size(values), current_of(carriers), max_of(carriers)}
  end

  defp carrier_sizes(_other), do: {0, 0, 0}

  # Modern OTP: {:blocks, [{alloc_type, [{:size, current, last, max}]}]}
  # Older OTP:  {:blocks_size, current, last, max}
  defp blocks_size(values) do
    case find(values, :blocks) do
      {:blocks, blocks} ->
        Enum.reduce(blocks, 0, fn {_type, sizes}, acc -> acc + current_of(find(sizes, :size)) end)

      _other ->
        current_of(find(values, :blocks_size))
    end
  end

  # These are property lists whose entries are four-element tuples, so the
  # Keyword functions cannot read them — Keyword.get/3 raises on the first
  # entry that is not a pair.
  defp find(properties, tag) when is_list(properties), do: List.keyfind(properties, tag, 0)
  defp find(_properties, _tag), do: nil

  defp current_of({_tag, current, _last, _max}), do: current
  defp current_of({_tag, current}) when is_integer(current), do: current
  defp current_of(_other), do: 0

  defp max_of({_tag, _current, _last, max}), do: max
  defp max_of(_other), do: 0

  defp total(readings) do
    {block, carrier, max_carrier} =
      Enum.reduce(readings, {0, 0, 0}, fn reading, acc ->
        add(acc, {reading.block_size, reading.carrier_size, reading.max_carrier_size})
      end)

    reading("total", :total, block, carrier, max_carrier)
  end

  # Utilisation is the whole point of putting blocks and carriers side by side:
  # it is the share of what the node holds from the OS that the program is
  # actually using. A low figure on a large allocator is fragmentation —
  # memory the node will not give back and cannot reuse.
  defp reading(id, name, block, carrier, max_carrier) do
    %{
      id: id,
      name: name,
      block_size: block,
      carrier_size: carrier,
      max_carrier_size: max_carrier,
      utilisation: utilisation(block, carrier)
    }
  end

  defp utilisation(_block, 0), do: 0.0
  defp utilisation(block, carrier), do: block / carrier * 100

  defp add({a1, b1, c1}, {a2, b2, c2}), do: {a1 + a2, b1 + b2, c1 + c2}
end
