defmodule RetroHexChat.Channels.Mutes do
  @moduledoc """
  Durable channel mute persistence and expiry orchestration.
  """

  import Ecto.Query

  alias RetroHexChat.Channels.ChannelMute
  alias RetroHexChat.Jobs
  alias RetroHexChat.Jobs.ChannelMuteExpiryWorker
  alias RetroHexChat.Repo

  @system_actor "system"

  @type revoke_summary :: %{revoked: non_neg_integer()}
  @type expiry_result ::
          {:expired, ChannelMute.t()}
          | {:noop, ChannelMute.t()}
          | {:not_due, ChannelMute.t(), pos_integer()}

  @doc "Creates or updates the active durable mute for a channel target."
  @spec mute(String.t(), String.t(), String.t(), non_neg_integer() | :permanent, keyword()) ::
          {:ok, ChannelMute.t()} | {:error, term()}
  def mute(channel_name, operator_nickname, target_nickname, duration, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    reason = Keyword.get(opts, :reason)
    expires_at = expires_at(duration, now)

    Repo.transaction(fn ->
      with {:ok, mute} <-
             upsert_unrevoked_mute(
               channel_name,
               operator_nickname,
               target_nickname,
               reason,
               expires_at
             ),
           :ok <- replace_expiry_job(mute) do
        mute
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc "Revokes any non-revoked mute for a channel target and cancels pending expiry jobs."
  @spec revoke_active(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, revoke_summary()} | {:error, term()}
  def revoke_active(channel_name, target_nickname, operator_nickname, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    Repo.transaction(fn ->
      mutes = list_unrevoked_for_target(channel_name, target_nickname)

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

  @doc "Materializes a due temporary mute as expired."
  @spec expire_due(pos_integer(), keyword()) :: {:ok, expiry_result()} | {:error, term()}
  def expire_due(mute_id, opts \\ []) when is_integer(mute_id) and mute_id > 0 do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    Repo.transaction(fn ->
      case mark_expired(mute_id, now) do
        {:ok, %ChannelMute{} = mute} ->
          {:expired, mute}

        {:skip, reason} ->
          reason
      end
    end)
  end

  @doc "Returns active mute records for a channel."
  @spec active_mutes(String.t(), keyword()) :: [ChannelMute.t()]
  def active_mutes(channel_name, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    ChannelMute
    |> active_query(now)
    |> where([mute], mute.channel_name == ^channel_name)
    |> order_by([mute], asc: mute.target_nickname)
    |> Repo.all()
  end

  @doc "Returns active muted nicknames for a channel."
  @spec active_nicknames(String.t(), keyword()) :: [String.t()]
  def active_nicknames(channel_name, opts \\ []) do
    channel_name
    |> active_mutes(opts)
    |> Enum.map(& &1.target_nickname)
  end

  @doc "Counts active channel mutes."
  @spec active_count(keyword()) :: non_neg_integer()
  def active_count(opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    ChannelMute
    |> active_query(now)
    |> Repo.aggregate(:count, :id)
  end

  @doc "Counts temporary mutes waiting for expiry materialization."
  @spec expired_count(keyword()) :: non_neg_integer()
  def expired_count(opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    ChannelMute
    |> due_query(now)
    |> Repo.aggregate(:count, :id)
  end

  defp upsert_unrevoked_mute(
         channel_name,
         operator_nickname,
         target_nickname,
         reason,
         expires_at
       ) do
    attrs = %{
      channel_name: channel_name,
      operator_nickname: operator_nickname,
      target_nickname: target_nickname,
      reason: reason,
      expires_at: expires_at,
      revoked_at: nil,
      revoked_by_nickname: nil,
      revoke_reason: nil
    }

    case get_unrevoked(channel_name, target_nickname) do
      nil ->
        %ChannelMute{}
        |> ChannelMute.changeset(attrs)
        |> Repo.insert()

      %ChannelMute{} = mute ->
        mute
        |> ChannelMute.changeset(attrs)
        |> Repo.update()
    end
  end

  defp replace_expiry_job(%ChannelMute{} = mute) do
    with :ok <- cancel_expiry_jobs([mute]) do
      schedule_expiry_job(mute)
    end
  end

  defp schedule_expiry_job(%ChannelMute{expires_at: nil}), do: :ok

  defp schedule_expiry_job(%ChannelMute{id: mute_id, expires_at: %DateTime{} = expires_at}) do
    %{mute_id: mute_id}
    |> ChannelMuteExpiryWorker.new(scheduled_at: expires_at)
    |> Jobs.insert()
    |> case do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp cancel_expiry_jobs(mutes) do
    Enum.each(mutes, fn mute ->
      {:ok, _count} =
        Jobs.cancel_worker_jobs(ChannelMuteExpiryWorker, :maintenance, %{"mute_id" => mute.id})
    end)

    :ok
  end

  defp mark_expired(mute_id, now) do
    query =
      ChannelMute
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
      1 -> {:ok, Repo.get!(ChannelMute, mute_id)}
      0 -> {:skip, classify_not_expired(mute_id, now)}
    end
  end

  defp classify_not_expired(mute_id, now) do
    case Repo.get(ChannelMute, mute_id) do
      nil ->
        Repo.rollback(:not_found)

      %ChannelMute{revoked_at: %DateTime{}} = mute ->
        {:noop, mute}

      %ChannelMute{expires_at: nil} ->
        Repo.rollback(:permanent_mute)

      %ChannelMute{expires_at: %DateTime{} = expires_at} = mute ->
        seconds = max(DateTime.diff(expires_at, now, :second), 1)
        {:not_due, mute, seconds}
    end
  end

  defp get_unrevoked(channel_name, target_nickname) do
    ChannelMute
    |> where([mute], mute.channel_name == ^channel_name)
    |> where([mute], mute.normalized_target == ^normalize_nick(target_nickname))
    |> where([mute], is_nil(mute.revoked_at))
    |> order_by([mute], desc: mute.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp list_unrevoked_for_target(channel_name, target_nickname) do
    ChannelMute
    |> where([mute], mute.channel_name == ^channel_name)
    |> where([mute], mute.normalized_target == ^normalize_nick(target_nickname))
    |> where([mute], is_nil(mute.revoked_at))
    |> Repo.all()
  end

  defp update_revoked_query([]), do: where(ChannelMute, [mute], false)

  defp update_revoked_query(ids) do
    ChannelMute
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

  defp normalize_nick(nickname) when is_binary(nickname), do: String.downcase(nickname)
end
