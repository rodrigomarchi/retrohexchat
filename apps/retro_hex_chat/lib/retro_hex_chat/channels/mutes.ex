defmodule RetroHexChat.Channels.Mutes do
  @moduledoc """
  Durable channel mute persistence and expiry orchestration.

  A channel mute restricts one nickname inside one channel, so the channel name
  is part of the key: the same person can be muted in several channels at once,
  each with its own duration.
  """

  alias RetroHexChat.Channels.ChannelMute
  alias RetroHexChat.Jobs.ChannelMuteExpiryWorker
  alias RetroHexChat.Moderation.TimedRestriction

  @restriction TimedRestriction.new!(
                 schema: ChannelMute,
                 worker: ChannelMuteExpiryWorker,
                 queue: :maintenance,
                 job_args_key: :mute_id,
                 subject_attr: :target_nickname,
                 subject_field: :normalized_target,
                 scope_fields: [:channel_name]
               )

  @type revoke_summary :: TimedRestriction.revoke_summary()
  @type expiry_result ::
          {:expired, ChannelMute.t()}
          | {:noop, ChannelMute.t()}
          | {:not_due, ChannelMute.t(), pos_integer()}

  @doc "Creates or updates the active durable mute for a channel target."
  @spec mute(String.t(), String.t(), String.t(), non_neg_integer() | :permanent, keyword()) ::
          {:ok, ChannelMute.t()} | {:error, term()}
  def mute(channel_name, operator_nickname, target_nickname, duration, opts \\ []) do
    TimedRestriction.put(
      @restriction,
      %{
        channel_name: channel_name,
        target_nickname: target_nickname,
        operator_nickname: operator_nickname,
        reason: Keyword.get(opts, :reason)
      },
      duration,
      Keyword.take(opts, [:now])
    )
  end

  @doc "Revokes any non-revoked mute for a channel target and cancels pending expiry jobs."
  @spec revoke_active(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, revoke_summary()} | {:error, term()}
  def revoke_active(channel_name, target_nickname, operator_nickname, opts \\ []) do
    TimedRestriction.revoke_active(
      @restriction,
      target_nickname,
      operator_nickname,
      [scope: [channel_name: channel_name]] ++ Keyword.take(opts, [:now])
    )
  end

  @doc "Materializes a due temporary mute as expired."
  @spec expire_due(pos_integer(), keyword()) :: {:ok, expiry_result()} | {:error, term()}
  def expire_due(mute_id, opts \\ []) when is_integer(mute_id) and mute_id > 0 do
    TimedRestriction.expire_due(@restriction, mute_id, Keyword.take(opts, [:now]))
  end

  @doc "Returns active mute records for a channel."
  @spec active_mutes(String.t(), keyword()) :: [ChannelMute.t()]
  def active_mutes(channel_name, opts \\ []) do
    TimedRestriction.list_active(
      @restriction,
      [scope: [channel_name: channel_name]] ++ Keyword.take(opts, [:now])
    )
  end

  @doc "Returns active muted nicknames for a channel."
  @spec active_nicknames(String.t(), keyword()) :: [String.t()]
  def active_nicknames(channel_name, opts \\ []) do
    channel_name
    |> active_mutes(opts)
    |> Enum.map(& &1.target_nickname)
  end

  @doc "Counts active channel mutes across every channel."
  @spec active_count(keyword()) :: non_neg_integer()
  def active_count(opts \\ []), do: TimedRestriction.active_count(@restriction, opts)

  @doc "Counts temporary mutes waiting for expiry materialization."
  @spec expired_count(keyword()) :: non_neg_integer()
  def expired_count(opts \\ []), do: TimedRestriction.due_count(@restriction, opts)
end
