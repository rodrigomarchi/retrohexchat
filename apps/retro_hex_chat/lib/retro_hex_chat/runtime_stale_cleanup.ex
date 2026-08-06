defmodule RetroHexChat.RuntimeStaleCleanup do
  @moduledoc """
  Reconciles stale durable records left open by runtime lobby, arcade and calls.

  The live OTP processes still own real-time UX timeouts. This module only
  materializes records that stayed non-terminal long after any healthy runtime
  process should have updated or closed them.
  """

  alias RetroHexChat.Arcade.Queries, as: ArcadeQueries
  alias RetroHexChat.GroupCall.Queries, as: GroupCallQueries
  alias RetroHexChat.Lobby.Queries, as: LobbyQueries

  @default_limit 100
  @default_stale_after_seconds 24 * 60 * 60

  @type domain_summary :: %{
          candidates: non_neg_integer(),
          expired: non_neg_integer(),
          skipped: non_neg_integer()
        }

  @type summary :: %{
          cutoff: DateTime.t(),
          limit: pos_integer(),
          lobby: domain_summary(),
          arcade: domain_summary(),
          group_call: domain_summary()
        }

  @type count_summary :: %{
          cutoff: DateTime.t(),
          lobby: non_neg_integer(),
          arcade: non_neg_integer(),
          group_call: non_neg_integer(),
          total: non_neg_integer()
        }

  @doc "Default age for durable runtime records before stale cleanup considers them abandoned."
  @spec default_stale_after_seconds() :: pos_integer()
  def default_stale_after_seconds, do: @default_stale_after_seconds

  @doc "Expires stale non-terminal lobby, arcade and group-call records."
  @spec cleanup(keyword()) :: {:ok, summary()} | {:error, term()}
  def cleanup(opts \\ []) do
    limit = positive_opt(opts, :limit, @default_limit)
    cutoff = cutoff(opts)

    with {:ok, lobby} <- cleanup_lobby(cutoff, limit),
         {:ok, arcade} <- cleanup_arcade(cutoff, limit),
         {:ok, group_call} <- cleanup_group_call(cutoff, limit) do
      {:ok,
       %{
         cutoff: cutoff,
         limit: limit,
         lobby: lobby,
         arcade: arcade,
         group_call: group_call
       }}
    end
  end

  @doc "Counts stale records with the same cutoff contract used by cleanup."
  @spec counts(keyword()) :: count_summary()
  def counts(opts \\ []) do
    cutoff = cutoff(opts)
    lobby = LobbyQueries.stale_session_count(cutoff)
    arcade = ArcadeQueries.stale_session_count(cutoff)
    group_call = GroupCallQueries.stale_room_count(cutoff)

    %{
      cutoff: cutoff,
      lobby: lobby,
      arcade: arcade,
      group_call: group_call,
      total: lobby + arcade + group_call
    }
  end

  defp cleanup_lobby(cutoff, limit) do
    cutoff
    |> LobbyQueries.list_stale_sessions(limit: limit)
    |> cleanup_candidates(&LobbyQueries.expire_stale_session(&1, cutoff))
  end

  defp cleanup_arcade(cutoff, limit) do
    cutoff
    |> ArcadeQueries.list_stale_sessions(limit: limit)
    |> cleanup_candidates(&ArcadeQueries.expire_stale_session(&1, cutoff))
  end

  defp cleanup_group_call(cutoff, limit) do
    cutoff
    |> GroupCallQueries.list_stale_rooms(limit: limit)
    |> cleanup_candidates(&GroupCallQueries.expire_stale_room(&1, cutoff))
  end

  defp cleanup_candidates(candidates, expire_fun) do
    initial = %{candidates: length(candidates), expired: 0, skipped: 0}

    Enum.reduce_while(candidates, {:ok, initial}, fn candidate, {:ok, summary} ->
      case expire_fun.(candidate) do
        {:ok, :expired} -> {:cont, {:ok, Map.update!(summary, :expired, &(&1 + 1))}}
        {:ok, :skipped} -> {:cont, {:ok, Map.update!(summary, :skipped, &(&1 + 1))}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp cutoff(opts) do
    case Keyword.get(opts, :cutoff) do
      %DateTime{} = cutoff ->
        cutoff

      _value ->
        now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

        stale_after_seconds =
          positive_opt(opts, :stale_after_seconds, @default_stale_after_seconds)

        DateTime.add(now, -stale_after_seconds, :second)
    end
  end

  defp positive_opt(opts, key, default) do
    case Keyword.get(opts, key) do
      value when is_integer(value) and value > 0 -> value
      _value -> default
    end
  end
end
