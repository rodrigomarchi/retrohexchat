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

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry

  @type snapshot :: %{
          name: String.t(),
          topic: String.t() | nil,
          member_count: non_neg_integer(),
          secret?: boolean(),
          private?: boolean(),
          invite_only?: boolean(),
          modes: String.t()
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
