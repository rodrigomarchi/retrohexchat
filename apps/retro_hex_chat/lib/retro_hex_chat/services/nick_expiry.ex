defmodule RetroHexChat.Services.NickExpiry do
  @moduledoc "Domain logic for purging inactive registered nicknames."
  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Admin.RoleCache
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.Queries

  @default_expiration_days 7

  @type purge_result :: %{
          expired_count: non_neg_integer(),
          candidate_count: non_neg_integer(),
          purged_count: non_neg_integer(),
          purged_names: [String.t()],
          protected_identified_count: non_neg_integer(),
          protected_admin_count: non_neg_integer(),
          founder_promotions: non_neg_integer(),
          orphaned_channels_removed: non_neg_integer(),
          access_removed: non_neg_integer(),
          bans_removed: non_neg_integer(),
          ban_exceptions_removed: non_neg_integer(),
          invite_exceptions_removed: non_neg_integer(),
          welcome_messages_removed: non_neg_integer()
        }

  @spec default_expiration_days() :: pos_integer()
  def default_expiration_days, do: @default_expiration_days

  @spec expired_count() :: non_neg_integer()
  @spec expired_count(keyword()) :: non_neg_integer()
  def expired_count(opts \\ []) do
    expiration_days = Keyword.get(opts, :expiration_days, @default_expiration_days)
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    nickserv = Keyword.get(opts, :nickserv, NickServ)
    protected = protected_nicks(nickserv)

    Queries.expired_nick_count(expiration_days, now, protected)
  end

  @spec purge() :: purge_result()
  @spec purge(keyword()) :: purge_result()
  def purge(opts \\ []) do
    expiration_days = Keyword.get(opts, :expiration_days, @default_expiration_days)
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    nickserv = Keyword.get(opts, :nickserv, NickServ)

    identified = identified_nicks(nickserv)
    admin_nicks = admin_protected_nicks()
    protected = Enum.uniq(identified ++ admin_nicks)
    expired_names = Queries.list_expired_nicknames(expiration_days, now)
    candidate_names = candidate_names(expired_names, protected)

    {count, purged_names} =
      Queries.purge_expired_nicks(expiration_days, protected, now, candidate_names)

    Enum.each(purged_names, &NickServ.remove_identified(&1, nickserv))

    succession = handle_founder_succession(purged_names)

    if count > 0 do
      Logger.info("nick_expiry_stop candidates=#{length(candidate_names)} purged=#{count}")
    end

    Map.merge(succession, %{
      expired_count: length(expired_names),
      candidate_count: length(candidate_names),
      purged_count: count,
      purged_names: purged_names,
      protected_identified_count: protected_count(expired_names, identified),
      protected_admin_count: protected_count(expired_names, admin_nicks)
    })
  end

  defp candidate_names(expired_names, protected) do
    protected = MapSet.new(protected)

    Enum.reject(expired_names, &MapSet.member?(protected, &1))
  end

  defp protected_count(expired_names, protected) do
    protected = MapSet.new(protected)

    Enum.count(expired_names, &MapSet.member?(protected, &1))
  end

  defp handle_founder_succession(nicknames) do
    nicknames
    |> Enum.map(&handle_expired_founder/1)
    |> Enum.reduce(empty_succession(), &merge_counts/2)
  end

  defp handle_expired_founder(nick) do
    channels = Queries.list_channels_for_founder(nick)
    access_removed = Queries.remove_access_for_nick(nick)

    channels
    |> Enum.map(&succeed_or_deregister/1)
    |> Enum.reduce(%{empty_succession() | access_removed: access_removed}, &merge_counts/2)
  end

  defp succeed_or_deregister(channel_name) do
    {:ok, result} =
      Repo.transaction(fn ->
        case Queries.find_next_successor(channel_name) do
          nil ->
            cleanup_and_delete_channel(channel_name)

          successor ->
            promote_successor(channel_name, successor)
        end
      end)

    result
  end

  defp promote_successor(channel_name, successor) do
    access_removed =
      case Queries.remove_access(channel_name, successor.nickname) do
        :ok -> 1
        {:error, :not_found} -> 0
      end

    {:ok, _entry} =
      Queries.add_access(
        channel_name,
        successor.nickname,
        "founder",
        dgettext("services", "NickExpiry")
      )

    :ok = Queries.update_channel_founder(channel_name, successor.nickname)

    Logger.info("NickExpiry: promoted #{successor.nickname} to founder of #{channel_name}")

    %{empty_succession() | founder_promotions: 1, access_removed: access_removed}
  end

  defp cleanup_and_delete_channel(channel_name) do
    cleanup = cleanup_channel(channel_name)

    channel_removed =
      case Queries.find_registered_channel(channel_name) do
        nil ->
          0

        channel ->
          {:ok, _channel} = Queries.delete_registered_channel(channel)
          1
      end

    if channel_removed > 0 do
      Logger.info("NickExpiry: deregistered orphaned channel #{channel_name}")
    end

    %{cleanup | orphaned_channels_removed: channel_removed}
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
      empty_succession()
      | access_removed: access_removed,
        bans_removed: bans_removed,
        ban_exceptions_removed: ban_exceptions_removed,
        invite_exceptions_removed: invite_exceptions_removed,
        welcome_messages_removed: welcome_messages_removed
    }
  end

  defp empty_succession do
    %{
      founder_promotions: 0,
      orphaned_channels_removed: 0,
      access_removed: 0,
      bans_removed: 0,
      ban_exceptions_removed: 0,
      invite_exceptions_removed: 0,
      welcome_messages_removed: 0
    }
  end

  defp merge_counts(counts, acc) do
    Map.merge(acc, counts, fn _key, left, right -> left + right end)
  end

  defp protected_nicks(nickserv),
    do: Enum.uniq(identified_nicks(nickserv) ++ admin_protected_nicks())

  defp identified_nicks(nickserv) do
    NickServ.list_identified(nickserv)
  rescue
    _error -> []
  catch
    :exit, _reason -> []
  end

  defp admin_protected_nicks do
    root_admins = Application.get_env(:retro_hex_chat, :root_admins, [])

    db_admins =
      try do
        RoleCache.list_admin_nicks()
      rescue
        _error -> []
      end

    root_admins ++ db_admins
  end
end
