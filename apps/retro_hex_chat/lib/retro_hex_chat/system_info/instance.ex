defmodule RetroHexChat.SystemInfo.Instance do
  @moduledoc """
  What the application itself is currently carrying.

  Everything else in `SystemInfo` describes a BEAM node and would read the same
  for any Elixir program. This is the one view that knows what this program is
  for: channels, the people in them, calls in progress, virtual spaces alive.

  Counting people is deliberately not done by listing them. Presence answers
  `list/1` with every tracked entry's full metadata — nickname, away state,
  timestamps — and building that for every channel merely to take a count means
  allocating a map per user per channel on every refresh. Only the keys are
  needed to count distinct nicknames, so only the keys are taken.
  """

  alias RetroHexChat.Channels
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Table

  @type t :: %__MODULE__{
          channel_count: non_neg_integer(),
          user_count: non_neg_integer(),
          group_call_rooms: non_neg_integer(),
          group_call_peers: non_neg_integer(),
          virtual_spaces: non_neg_integer(),
          channels: [channel()]
        }

  @type channel :: %{name: String.t(), users: non_neg_integer()}

  defstruct channel_count: 0,
            user_count: 0,
            group_call_rooms: 0,
            group_call_peers: 0,
            virtual_spaces: 0,
            channels: []

  @doc "Reads the application's current occupancy."
  @spec current() :: t()
  def current do
    channels = channel_names()
    occupancy = Enum.map(channels, &%{name: &1, users: length(nicknames(&1))})

    %__MODULE__{
      channel_count: length(channels),
      user_count: distinct_user_count(channels),
      group_call_rooms: active_children(RetroHexChat.GroupCall.RoomSupervisor),
      group_call_peers: registered(RetroHexChat.GroupCall.PeerRegistry),
      virtual_spaces: active_children(RetroHexChat.VirtualSpace.Supervisor),
      channels: Enum.sort_by(occupancy, & &1.users, :desc)
    }
  end

  @doc "Columns for the per-channel occupancy listing."
  @spec channel_columns() :: [Table.column()]
  def channel_columns do
    [
      Table.column(:name, "Channel", sortable: true),
      Table.column(:users, "Users", format: :number, sortable: true)
    ]
  end

  @doc "The per-channel occupancy as a table."
  @spec channel_table(t()) :: Table.t()
  def channel_table(%__MODULE__{channels: channels}) do
    Table.from_list(channel_columns(), channels, &Map.put(&1, :id, &1.name))
  end

  defp channel_names do
    Channels.Registry.registry_name()
    |> Registry.select([{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.sort()
  end

  # One person in five channels is one person. The union of keys answers that
  # without materialising a single metadata map.
  defp distinct_user_count(channels) do
    channels
    |> Enum.reduce(MapSet.new(), fn channel, acc ->
      channel |> nicknames() |> MapSet.new() |> MapSet.union(acc)
    end)
    |> MapSet.size()
  end

  defp nicknames(channel) do
    "channel:#{channel}"
    |> Tracker.list()
    |> Map.keys()
  end

  # A supervisor that has not started on this node counts as empty rather than
  # raising: the runtime windows must render on a partially booted node too.
  defp active_children(supervisor) do
    %{active: active} = DynamicSupervisor.count_children(supervisor)
    active
  rescue
    _error -> 0
  catch
    :exit, _reason -> 0
  end

  defp registered(registry) do
    Registry.count(registry)
  rescue
    _error -> 0
  catch
    :exit, _reason -> 0
  end
end
