defmodule RetroHexChat.Channels.Directory do
  @moduledoc """
  The channel directory: what `/list` reads.

  Each channel server keeps a small snapshot of its own directory-visible state
  — name, topic, member count, the handful of modes that affect visibility — in
  its own `Registry` value. Reading the directory is then a single ETS select
  over that registry.

  Before this, listing channels meant a synchronous `GenServer.call` **per
  channel** to fetch a full state map and then throwing almost all of it away.
  On a busy server that is N blocking round trips every time someone opens the
  channel list, and every one of them queues behind whatever that channel is
  currently doing.

  The snapshot is deliberately tiny: only what the directory renders. Anything
  else still goes through `Server.get_state/1`.
  """

  alias RetroHexChat.Channels.Modes
  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Services.Queries, as: ServiceQueries

  @type snapshot :: %{
          name: String.t(),
          topic: String.t() | nil,
          member_count: non_neg_integer(),
          secret?: boolean(),
          private?: boolean(),
          invite_only?: boolean(),
          modes: String.t()
        }

  @typedoc """
  One row of the catalogue: a snapshot plus whether anybody is holding the
  channel open, and when it last had something happen in it.

  `live?` and `last_activity_at` are on every row, live or cold, because the
  thing that renders them renders both — a cold row shaped differently is a
  second row type in disguise.
  """
  @type entry :: %{
          name: String.t(),
          topic: String.t() | nil,
          member_count: non_neg_integer(),
          secret?: boolean(),
          private?: boolean(),
          invite_only?: boolean(),
          modes: String.t(),
          live?: boolean(),
          last_activity_at: DateTime.t() | nil
        }

  @doc "Builds the directory snapshot a channel publishes about itself."
  @spec snapshot(map()) :: snapshot()
  def snapshot(%{name: name} = state) do
    %{
      name: name,
      topic: Map.get(state, :topic),
      member_count: Map.get(state, :member_count, 0),
      secret?: get_in(state, [:modes_detail, :secret]) || false,
      private?: get_in(state, [:modes_detail, :private]) || false,
      invite_only?: get_in(state, [:modes_detail, :invite_only]) || false,
      modes: Map.get(state, :modes, "")
    }
  end

  @doc """
  Publishes a channel's snapshot into its registry entry.

  Called by the channel server itself whenever directory-visible state changes.
  Safe to call from any process that owns the registration; a channel that is
  not registered (during shutdown) is a no-op.
  """
  @spec publish(String.t(), snapshot()) :: :ok
  def publish(channel_name, snapshot) do
    Registry.update_value(ChannelRegistry.registry_name(), channel_name, fn _ -> snapshot end)
    :ok
  rescue
    # update_value raises if this process does not own the registration, which
    # happens only in tests that drive the module directly. The directory is a
    # read cache; failing to refresh it must never take a channel down.
    ArgumentError -> :ok
  end

  @doc """
  Every channel's snapshot, alphabetical. One ETS select, no process messages.

  Channels registered before they published a snapshot (a race with startup)
  are skipped rather than rendered with placeholder data.
  """
  @spec all() :: [snapshot()]
  def all do
    ChannelRegistry.registry_name()
    |> Registry.select([{{:"$1", :_, :"$2"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.flat_map(fn
      {_name, snapshot} when is_map(snapshot) -> [snapshot]
      _unpublished -> []
    end)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Every channel somebody could join, running or not.

  `all/0` answers from the process registry, which means a room everybody left
  is gone from it — and gone from `/list`, and gone for whoever arrives next.
  A registered channel that nobody is in is still a place; it just has nobody
  in it, and that is what `member_count: 0` says.

  Live rows come first, busiest first, because a catalogue that interleaves the
  two hides where there are people. Cold rows follow by how recently anything
  happened in them.

  Options: `:search` (name or topic, applied to both halves) and `:limit` for
  the cold half.
  """
  @spec catalog(keyword()) :: [entry()]
  def catalog(opts \\ []) do
    live =
      case Keyword.get(opts, :search) do
        nil -> all()
        term -> search(term)
      end

    live_names = live |> Enum.map(& &1.name) |> Enum.uniq()

    # Two questions, two queries. The cold half is capped, so the names already
    # in hand are excluded inside it rather than dropped after: a row removed
    # once `limit` has counted it spends a slot nobody sees. The live half is
    # looked up by name, uncapped, only to learn when each room was last used —
    # a fact that lives in the table and not in the process.
    cold =
      opts
      |> Keyword.take([:search, :limit])
      |> Keyword.put(:exclude, live_names)
      |> ServiceQueries.list_registered_channels()

    by_name =
      live_names
      |> ServiceQueries.list_registered_channels_by_name()
      |> Map.new(&{&1.name, &1})

    live_entries =
      live
      |> Enum.sort_by(&{-&1.member_count, &1.name})
      |> Enum.map(&live_entry(&1, by_name))

    cold_entries = Enum.map(cold, &cold_entry/1)

    live_entries ++ cold_entries
  end

  # A running channel keeps its membership and modes in memory but not the day
  # it was last used — that lives in the row, and an empty room is exactly when
  # somebody wants to know it.
  defp live_entry(snapshot, by_name) do
    Map.merge(snapshot, %{
      live?: true,
      last_activity_at: get_in(by_name, [snapshot.name, Access.key(:last_activity_at)])
    })
  end

  # A cold channel's modes live in a column rather than in a process, so they
  # are decoded the same way the channel itself decodes them when it starts.
  defp cold_entry(row) do
    modes = Modes.from_string(row.modes)

    %{
      name: row.name,
      topic: row.topic,
      member_count: 0,
      secret?: Modes.secret?(modes),
      private?: Modes.private?(modes),
      invite_only?: Modes.invite_only?(modes),
      modes: row.modes || "",
      live?: false,
      last_activity_at: row.last_activity_at
    }
  end

  @doc """
  Snapshots whose name or topic contains `term`, case-insensitively.

  The filter runs where the data is rather than after materialising the whole
  directory into the caller.
  """
  @spec search(String.t()) :: [snapshot()]
  def search(term) when is_binary(term) do
    case String.trim(term) do
      "" -> all()
      trimmed -> Enum.filter(all(), &matches?(&1, String.downcase(trimmed)))
    end
  end

  @spec matches?(snapshot(), String.t()) :: boolean()
  defp matches?(snapshot, term) do
    String.contains?(String.downcase(snapshot.name), term) or
      String.contains?(String.downcase(snapshot.topic || ""), term)
  end
end
