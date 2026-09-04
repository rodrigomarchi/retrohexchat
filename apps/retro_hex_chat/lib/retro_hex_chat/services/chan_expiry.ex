defmodule RetroHexChat.Services.ChanExpiry do
  @moduledoc "Domain logic for purging inactive registered channels."

  require Logger

  alias RetroHexChat.Services.Queries

  @default_expiration_days 7

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

  @spec expired_count() :: non_neg_integer()
  @spec expired_count(keyword()) :: non_neg_integer()
  def expired_count(opts \\ []) do
    expiration_days = Keyword.get(opts, :expiration_days, @default_expiration_days)
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    Queries.expired_channel_count(expiration_days, now)
  end

  @spec purge() :: purge_result()
  @spec purge(keyword()) :: purge_result()
  def purge(opts \\ []) do
    expiration_days = Keyword.get(opts, :expiration_days, @default_expiration_days)
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    names = Queries.list_expired_channel_names(expiration_days, now)
    cleanup = cleanup_channels(names)
    {count, purged_names} = Queries.purge_expired_channels(expiration_days, now, names)

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
    |> Enum.map(&cleanup_channel/1)
    |> Enum.reduce(empty_cleanup(), &merge_cleanup/2)
  end

  defp cleanup_channel(channel_name) do
    access_removed =
      channel_name
      |> Queries.all_access()
      |> Enum.count(fn entry -> Queries.remove_access(channel_name, entry.nickname) == :ok end)

    bans_removed =
      channel_name
      |> Queries.all_bans()
      |> Enum.count(fn ban -> Queries.remove_ban(channel_name, ban.banned_nickname) == :ok end)

    ban_exceptions_removed =
      channel_name
      |> Queries.all_ban_exceptions()
      |> Enum.count(fn entry ->
        Queries.remove_ban_exception(channel_name, entry.nickname) == :ok
      end)

    invite_exceptions_removed =
      channel_name
      |> Queries.all_invite_exceptions()
      |> Enum.count(fn entry ->
        Queries.remove_invite_exception(channel_name, entry.nickname) == :ok
      end)

    welcome_messages_removed =
      if Queries.get_welcome_message(channel_name) do
        Queries.delete_welcome_message(channel_name)
        1
      else
        0
      end

    %{
      access_removed: access_removed,
      bans_removed: bans_removed,
      ban_exceptions_removed: ban_exceptions_removed,
      invite_exceptions_removed: invite_exceptions_removed,
      welcome_messages_removed: welcome_messages_removed
    }
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
