defmodule RetroHexChat.Admin.GlobalMutes do
  @moduledoc """
  Durable server-wide mute management.

  A global mute restricts a nickname everywhere, so unlike a channel mute it has
  no scope beyond the nickname itself. `GlobalMuteTable` is a cache derived from
  this table, not the source of truth, and every write here keeps it in step —
  the expiry hook runs inside the transaction so a cache that refuses to update
  undoes the expiry rather than drifting from it.
  """

  alias RetroHexChat.Admin.{GlobalMute, GlobalMuteTable}
  alias RetroHexChat.Jobs.GlobalMuteExpiryWorker
  alias RetroHexChat.Moderation.TimedRestriction

  @system_actor "system"

  @restriction TimedRestriction.new!(
                 schema: GlobalMute,
                 worker: GlobalMuteExpiryWorker,
                 queue: :maintenance,
                 job_args_key: :mute_id,
                 subject_attr: :nickname,
                 subject_field: :normalized_nickname,
                 scope_fields: []
               )

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
    attrs = %{
      nickname: nickname,
      operator_nickname: operator_nickname || @system_actor,
      reason: reason
    }

    case TimedRestriction.put(@restriction, attrs, duration) do
      {:ok, mute} ->
        GlobalMuteTable.mute(mute.nickname, cache_expiry(mute))
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec unmute(String.t(), String.t()) :: :ok | {:error, term()}
  def unmute(nickname, operator_nickname \\ @system_actor) do
    case TimedRestriction.revoke_active(@restriction, nickname, operator_nickname) do
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
  def active_count(opts \\ []), do: TimedRestriction.active_count(@restriction, opts)

  @spec expired_count(keyword()) :: non_neg_integer()
  def expired_count(opts \\ []), do: TimedRestriction.due_count(@restriction, opts)

  @spec active_mutes(keyword()) :: [GlobalMute.t()]
  def active_mutes(opts \\ []), do: TimedRestriction.list_active(@restriction, opts)

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
    TimedRestriction.expire_due(
      @restriction,
      mute_id,
      [on_expired: &GlobalMuteTable.unmute(&1.nickname)] ++ Keyword.take(opts, [:now])
    )
  end

  defp cache_expiry(%GlobalMute{expires_at: nil}), do: :permanent
  defp cache_expiry(%GlobalMute{expires_at: %DateTime{} = expires_at}), do: expires_at
end
