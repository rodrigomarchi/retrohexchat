defmodule RetroHexChat.Services.ChanExpiry do
  @moduledoc "Domain logic for purging inactive registered channels."

  require Logger

  alias RetroHexChat.Channels.Server, as: ChannelServer
  alias RetroHexChat.Services.Queries

  @default_expiration_days 90

  @type purge_result :: %{
          candidate_count: non_neg_integer(),
          purged_count: non_neg_integer(),
          purged_names: [String.t()],
          access_removed: non_neg_integer(),
          bans_removed: non_neg_integer(),
          ban_exceptions_removed: non_neg_integer(),
          invite_exceptions_removed: non_neg_integer(),
          welcome_messages_removed: non_neg_integer()
        }

  @doc """
  How many days a registered channel may stay quiet before it is released.

  Read at call time for the same reason the nickname window is: a release that
  compiled the number in would ignore `RHC_CHANNEL_EXPIRY_DAYS`.
  """
  @spec configured_expiration_days() :: pos_integer()
  def configured_expiration_days do
    :retro_hex_chat
    |> Application.get_env(:expiry, [])
    |> Keyword.get(:channel_days, @default_expiration_days)
  end

  @spec expired_count() :: non_neg_integer()
  @spec expired_count(keyword()) :: non_neg_integer()
  def expired_count(opts \\ []) do
    expiration_days = Keyword.get(opts, :expiration_days, configured_expiration_days())
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    Queries.expired_channel_count(expiration_days, now)
  end

  @spec purge() :: purge_result()
  @spec purge(keyword()) :: purge_result()
  def purge(opts \\ []) do
    expiration_days = Keyword.get(opts, :expiration_days, configured_expiration_days())
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    names = Queries.list_expired_channel_names(expiration_days, now)
    cleanup = cleanup_channels(names)
    {count, purged_names} = Queries.purge_expired_channels(expiration_days, now, names)
    # A room somebody is still holding open forgets what only a registration kept.
    Enum.each(purged_names, &ChannelServer.mark_unregistered/1)

    if count > 0 do
      Logger.info("chan_expiry_stop candidates=#{length(names)} purged=#{count}")
    end

    Map.merge(cleanup, %{
      candidate_count: length(names),
      purged_count: count,
      purged_names: purged_names
    })
  end

  defp cleanup_channels(names) do
    names
    |> Enum.map(&Queries.purge_channel_records/1)
    |> Enum.reduce(empty_cleanup(), &merge_cleanup/2)
  end

  defp empty_cleanup do
    %{
      access_removed: 0,
      bans_removed: 0,
      ban_exceptions_removed: 0,
      invite_exceptions_removed: 0,
      welcome_messages_removed: 0
    }
  end

  defp merge_cleanup(cleanup, acc) do
    Map.merge(acc, cleanup, fn _key, left, right -> left + right end)
  end
end
