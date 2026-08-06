defmodule RetroHexChat.Admin.GlobalMutes do
  @moduledoc """
  Durable server-wide mute management.

  `GlobalMuteTable` is a cache derived from this table, not the source of truth.
  """

  import Ecto.Query

  alias RetroHexChat.Admin.{GlobalMute, GlobalMuteTable}
  alias RetroHexChat.Jobs
  alias RetroHexChat.Jobs.GlobalMuteExpiryWorker
  alias RetroHexChat.Repo

  @system_actor "system"

  @type expiry_result ::
          {:expired, GlobalMute.t()}
          | {:noop, GlobalMute.t()}
          | {:not_due, GlobalMute.t(), pos_integer()}

  @spec mute(String.t(), String.t() | nil, non_neg_integer() | :permanent) ::
          :ok | {:error, term()}
  def mute(nickname, reason \\ nil, duration \\ :permanent) do
    mute(nickname, @system_actor, reason, duration)
  end

  @spec mute(String.t(), String.t(), String.t() | nil, non_neg_integer() | :permanent) ::
          :ok | {:error, term()}
  def mute(nickname, operator_nickname, reason, duration) do
    now = DateTime.utc_now()
    expires_at = expires_at(duration, now)

    case persist_mute(nickname, operator_nickname, reason, expires_at) do
      {:ok, mute} ->
        GlobalMuteTable.mute(mute.nickname, cache_expiry(mute))
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec unmute(String.t(), String.t()) :: :ok | {:error, term()}
  def unmute(nickname, operator_nickname \\ @system_actor) do
    case revoke_active(nickname, operator_nickname) do
      {:ok, _summary} ->
        GlobalMuteTable.unmute(nickname)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec muted?(String.t()) :: boolean()
  def muted?(nickname) do
    GlobalMuteTable.muted?(nickname)
  end

  @spec active_count(keyword()) :: non_neg_integer()
  def active_count(opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    GlobalMute
    |> active_query(now)
    |> Repo.aggregate(:count, :id)
  end

  @spec expired_count(keyword()) :: non_neg_integer()
  def expired_count(opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    GlobalMute
    |> due_query(now)
    |> Repo.aggregate(:count, :id)
  end

  @spec active_mutes(keyword()) :: [GlobalMute.t()]
  def active_mutes(opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    GlobalMute
    |> active_query(now)
    |> order_by([mute], asc: mute.nickname)
    |> Repo.all()
  end

  @spec active_cache_entries() :: [{String.t(), :permanent | DateTime.t()}]
  def active_cache_entries do
    active_mutes()
    |> Enum.map(&{&1.nickname, cache_expiry(&1)})
  end

  @spec reload_cache() :: :ok
  def reload_cache do
    GlobalMuteTable.replace_all(active_cache_entries())
  end

  @spec expire_due(pos_integer(), keyword()) :: {:ok, expiry_result()} | {:error, term()}
  def expire_due(mute_id, opts \\ []) when is_integer(mute_id) and mute_id > 0 do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    Repo.transaction(fn ->
      case mark_expired(mute_id, now) do
        {:ok, %GlobalMute{} = mute} ->
          GlobalMuteTable.unmute(mute.nickname)
          {:expired, mute}

        {:skip, reason} ->
          reason
      end
    end)
  end

  defp persist_mute(nickname, operator_nickname, reason, expires_at) do
    Repo.transaction(fn ->
      with {:ok, mute} <- upsert_unrevoked_mute(nickname, operator_nickname, reason, expires_at),
           :ok <- replace_expiry_job(mute) do
        mute
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp revoke_active(nickname, operator_nickname) do
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      mutes = list_unrevoked_for_nickname(nickname)

      with :ok <- cancel_expiry_jobs(mutes) do
        ids = Enum.map(mutes, & &1.id)

        revoked =
          ids
          |> update_revoked_query()
          |> Repo.update_all(
            set: [
              revoked_at: now,
              revoked_by_nickname: operator_nickname,
              revoke_reason: "manual",
              updated_at: now
            ]
          )
          |> elem(0)

        %{revoked: revoked}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp upsert_unrevoked_mute(nickname, operator_nickname, reason, expires_at) do
    attrs = %{
      nickname: nickname,
      operator_nickname: operator_nickname || @system_actor,
      reason: reason,
      expires_at: expires_at,
      revoked_at: nil,
      revoked_by_nickname: nil,
      revoke_reason: nil
    }

    case get_unrevoked(nickname) do
      nil ->
        %GlobalMute{}
        |> GlobalMute.changeset(attrs)
        |> Repo.insert()

      %GlobalMute{} = mute ->
        mute
        |> GlobalMute.changeset(attrs)
        |> Repo.update()
    end
  end

  defp replace_expiry_job(%GlobalMute{} = mute) do
    with :ok <- cancel_expiry_jobs([mute]) do
      schedule_expiry_job(mute)
    end
  end

  defp schedule_expiry_job(%GlobalMute{expires_at: nil}), do: :ok

  defp schedule_expiry_job(%GlobalMute{id: mute_id, expires_at: %DateTime{} = expires_at}) do
    %{mute_id: mute_id}
    |> GlobalMuteExpiryWorker.new(scheduled_at: expires_at)
    |> Jobs.insert()
    |> case do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp cancel_expiry_jobs(mutes) do
    Enum.each(mutes, fn mute ->
      {:ok, _count} =
        Jobs.cancel_worker_jobs(GlobalMuteExpiryWorker, :maintenance, %{"mute_id" => mute.id})
    end)

    :ok
  end

  defp mark_expired(mute_id, now) do
    query =
      GlobalMute
      |> where([mute], mute.id == ^mute_id)
      |> due_query(now)

    {count, _records} =
      Repo.update_all(query,
        set: [
          revoked_at: now,
          revoked_by_nickname: @system_actor,
          revoke_reason: "expired",
          updated_at: now
        ]
      )

    case count do
      1 -> {:ok, Repo.get!(GlobalMute, mute_id)}
      0 -> {:skip, classify_not_expired(mute_id, now)}
    end
  end

  defp classify_not_expired(mute_id, now) do
    case Repo.get(GlobalMute, mute_id) do
      nil ->
        Repo.rollback(:not_found)

      %GlobalMute{revoked_at: %DateTime{}} = mute ->
        {:noop, mute}

      %GlobalMute{expires_at: nil} ->
        Repo.rollback(:permanent_mute)

      %GlobalMute{expires_at: %DateTime{} = expires_at} = mute ->
        seconds = max(DateTime.diff(expires_at, now, :second), 1)
        {:not_due, mute, seconds}
    end
  end

  defp get_unrevoked(nickname) do
    GlobalMute
    |> where([mute], mute.normalized_nickname == ^normalize_nickname(nickname))
    |> where([mute], is_nil(mute.revoked_at))
    |> order_by([mute], desc: mute.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp list_unrevoked_for_nickname(nickname) do
    GlobalMute
    |> where([mute], mute.normalized_nickname == ^normalize_nickname(nickname))
    |> where([mute], is_nil(mute.revoked_at))
    |> Repo.all()
  end

  defp update_revoked_query([]), do: where(GlobalMute, [mute], false)

  defp update_revoked_query(ids) do
    GlobalMute
    |> where([mute], mute.id in ^ids)
    |> where([mute], is_nil(mute.revoked_at))
  end

  defp active_query(queryable, now) do
    queryable
    |> where([mute], is_nil(mute.revoked_at))
    |> where([mute], is_nil(mute.expires_at) or mute.expires_at > ^now)
  end

  defp due_query(queryable, now) do
    queryable
    |> where([mute], is_nil(mute.revoked_at))
    |> where([mute], not is_nil(mute.expires_at))
    |> where([mute], mute.expires_at <= ^now)
  end

  defp expires_at(duration, now) when is_integer(duration) and duration > 0,
    do: DateTime.add(now, duration, :second)

  defp expires_at(_duration, _now), do: nil

  defp cache_expiry(%GlobalMute{expires_at: nil}), do: :permanent
  defp cache_expiry(%GlobalMute{expires_at: %DateTime{} = expires_at}), do: expires_at

  defp normalize_nickname(nickname) when is_binary(nickname), do: String.downcase(nickname)
end
